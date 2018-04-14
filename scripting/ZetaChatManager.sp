#pragma semicolon 1

#include <sdktools>
#include <clientprefs>
#include <CiderChatProcessor>

#define PLUGIN_VERSION "1.0.0"
#define MAXCHATCOLORS 20
#define ALIVE 0
#define DEAD 1

#define PREFIX 0
#define NAME   1
#define SUFFIX 2
#define TEXT   3

#define DATABASENAME "zetachat"

#define CHAT_PREFIX  (1 << 0)
#define CHAT_NAME    (1 << 2)
#define CHAT_SUFFIX  (1 << 1)
#define CHAT_TEXT    (1 << 3)
#define MAXTYPES  4
#define MAXTEAMS  3
#define MAXSTATES 2
#define MAXLENGTH_SQL 64
int defaultChat[MAXTYPES];

char serverAddress[64];
int serverGroup;

#define MAXCONFIG 100
//Stores the chat_config ids for each type (prefix, name, suffix, text).
int chatID[MAXCONFIG]; 
int chatType[MAXCONFIG];
int chatGroup[MAXCONFIG];
char chatValue[MAXCONFIG][MAXTYPES][MAXTEAMS][MAXSTATES][MAXLENGTH_SQL];
int chatPosition[MAXTYPES];

//Store flags needed for each group
int flagBit[MAXFLAGS]
int flagGroup[MAXFLAGS];
int flagCount;

bool dbLoaded;
bool dbLock;
Database dbChat;

public Plugin myinfo = {
    name = "Zeta Chat Manager",
    author = "Mitch",
    description = "Zeta Chat Manager",
    version = PLUGIN_VERSION,
    url = "mtch.tech"
};

public OnPluginStart() {

}

public void OnMapStart() {
    connectDatabase();
}

public void connectDatabase() {
    dbLoaded = false;
    if(!dbLock) {
        if(SQL_CheckConfig(DATABASENAME)) {
            Database.Connect(dbConnect, DATABASENAME);
        } else {
            SetFailState("Database config for '%s' not found. See README for setup guide.", DATABASENAME);
        }
    }
}

public void dbConnect(Database db, const char[] error, any data) {
    if(db == null) {
        LogMessage("Database failure: %s", error);
        return;
    }
    dbLock = true;
    dbChat = db;
    int hostip = GetConVarInt(FindConVar("hostip"));
    int hostport = GetConVarInt(FindConVar("hostport"));
    Format(serverAddress, sizeof(serverAddress), "%i.%i.%i.%i:%i", hostip >>> 24 & 255, hostip >>> 16 & 255, hostip >>> 8 & 255, hostip & 255, hostport);
    //Retrieve Server ID, if not make new serverId.
    char query[150];
    dbChat.Format(query, sizeof(query), "SELECT sg FROM chat_servers WHERE address='%s';", serverAddress);
    dbChat.Query(OnReceiveServerGroup, query, _, DBPrio_High);
}

public OnReceiveServerGroup(Database db, DBResultSet result, const char[] error, any data) {
    bool hasServerInDB = false;
    if(result != null) {
        serverGroup = -1;
        if(result.RowCount > 0) {
            hasServerInDB = true;
            while(result.FetchRow()) {
                serverGroup = result.FetchInt(0);
            }
        }
        delete result;
    } else {
        LogError("SQL error receiving tag cache: %s", error);
    }
    PrintToServer("serverGroup: %i", serverGroup);
    
    char sqlCopyPasta[64];
    if(serverGroup == -1) {
        LogMessage("Server does not belong to a group, this isn't an issue however it's recommended to set one.");
        Format(sqlCopyPasta, sizeof(sqlCopyPasta), "SELECT id FROM chat_groups WHERE sg = '-1'");
    } else {
        Format(sqlCopyPasta, sizeof(sqlCopyPasta), "SELECT id FROM chat_groups WHERE sg LIKE '%%%03d%%' OR sg = '-1'", serverGroup);
    }
    char sqlBuffer[256];
    Transaction transaction = new Transaction();
    // only if the server doesn't belong to a server group should we try and add the address.
    //Retrieve All configs Prefix, Name, Suffix and Text.
    Format(sqlBuffer, sizeof(sqlBuffer), "SELECT * FROM chat_config WHERE type='%i' AND gr IN (%s) ORDER BY pr DESC;", PREFIX, sqlCopyPasta);
    transaction.AddQuery(sqlBuffer, PREFIX);
    Format(sqlBuffer, sizeof(sqlBuffer), "SELECT * FROM chat_config WHERE type='%i' AND gr IN (%s) ORDER BY pr DESC;", NAME, sqlCopyPasta);
    transaction.AddQuery(sqlBuffer, NAME);
    Format(sqlBuffer, sizeof(sqlBuffer), "SELECT * FROM chat_config WHERE type='%i' AND gr IN (%s) ORDER BY pr DESC;", SUFFIX, sqlCopyPasta);
    transaction.AddQuery(sqlBuffer, SUFFIX);
    Format(sqlBuffer, sizeof(sqlBuffer), "SELECT * FROM chat_config WHERE type='%i' AND gr IN (%s) ORDER BY pr DESC;", TEXT, sqlCopyPasta);
    transaction.AddQuery(sqlBuffer, TEXT);
    //Retrieve flags?
    Format(sqlBuffer, sizeof(sqlBuffer), "SELECT flag, gr FROM chat_flags WHERE gr IN (%s);", sqlCopyPasta);
    transaction.AddQuery(sqlBuffer, -1);
    if(!hasServerInDB) {
        Format(sqlBuffer, sizeof(sqlBuffer), "INSERT INTO chat_servers (address, sg, disp) VALUES ('%s', -1, '%s');", serverAddress, serverAddress);
        transaction.AddQuery(sqlBuffer, -1337);
    }
    dbChat.Execute(transaction, loadConfigTransactionCallback, threadFailure);
}

public void loadConfigTransactionCallback(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData) {
    
    char tempBuffer[64];
    int tempInt;
    
    int cc = 0; // Holds the Config count 
    for(int x = 0; x < numQueries; x++) {
        if(queryData[x] >= 0) {
            if(results[x].RowCount) {
                while(results[x].FetchRow()) {
                    chatID[cc] = results[x].FetchInt(0);
                    chatType[cc] = results[x].FetchInt(1);
                    chatGroup[cc] = results[x].FetchInt(2);
                    results[x].FetchString(4,  chatDisplay[cc], MAXLENGTH_SQL);
                    results[x].FetchString(5,  chatValue[cc][queryData[x]][0][0], MAXLENGTH_SQL);
                    results[x].FetchString(6,  chatValue[cc][queryData[x]][0][1], MAXLENGTH_SQL);
                    results[x].FetchString(7,  chatValue[cc][queryData[x]][1][0], MAXLENGTH_SQL);
                    results[x].FetchString(8,  chatValue[cc][queryData[x]][1][1], MAXLENGTH_SQL);
                    results[x].FetchString(9,  chatValue[cc][queryData[x]][2][0], MAXLENGTH_SQL);
                    results[x].FetchString(10, chatValue[cc][queryData[x]][2][1], MAXLENGTH_SQL);
                    cc++;
                }
                chatPosition[x] = cc; //Where to end a loop later on.
            } else {
                chatPosition[x] = -1; //No configs for this exists.
            }
        } else if(queryData[x] == -1) {
            //Flags
            flagCount = 0;
            if(results[x].RowCount) {
                while(results[x].FetchRow()) {
                    results[x].FetchString(0, tempBuffer, MAXLENGTH_SQL);
                    
                    //Check if the flag is empty
                    if(!StrEqual(tempBuffer, "", false)) {
                        if(StrContains(tempBuffer, ",", false) >= 0) {
                            //Multiple flags
                        } else {
                            
                        }
                    }
                    
                    flagGroup[flagCount] = results[x].FetchInt(1);
                    flagCount++;
                }
            }
        }
    }
    dbLoaded = true;
    dbLock = false;
}

public void threadFailure(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData) {
    LogError("Error in Database Execution: %s (%i - #%i)", error, numQueries, failIndex);
}