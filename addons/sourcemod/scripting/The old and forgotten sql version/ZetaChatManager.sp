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
#define CHAT_NAME    (1 << 1)
#define CHAT_SUFFIX  (1 << 2)
#define CHAT_TEXT    (1 << 3)
#define MAXTYPES  4
#define MAXTEAMS  3
#define MAXSTATES 2
#define MAXLENGTH_SQL 64
int defaultChat[MAXTYPES];

char serverAddress[64];
int serverGroup;

#define MAXGROUPS 25
int plyGroups[MAXPLAYERS+1][MAXGROUPS]; // The groups a player exists under
int plyGroupCount[MAXPLAYERS+1]; // The groups a player exists under
//Stores the chat_config ids for each type (prefix, name, suffix, text).
int chatPosition[MAXTYPES];
ArrayList chatID;
ArrayList chatGroup;
ArrayList chatValid;
ArrayList chatDisplay;
ArrayList chatValue[MAXTEAMS][MAXSTATES];
//char chatValue[MAXCONFIG][MAXLENGTH_SQL];

//Store flags needed for each group
ArrayList flagBits;
ArrayList flagGroup;

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
    for(int t = PREFIX; t <= TEXT; t++) {
        Format(sqlBuffer, sizeof(sqlBuffer), "SELECT * FROM chat_config WHERE type=%i AND gr IN (%s) ORDER BY pr DESC;", t, sqlCopyPasta);
        transaction.AddQuery(sqlBuffer, t);
    }
    //Retrieve flags?
    Format(sqlBuffer, sizeof(sqlBuffer), "SELECT flag, gr FROM chat_ident WHERE type=0 AND gr IN (%s);", sqlCopyPasta);
    transaction.AddQuery(sqlBuffer, -1);
    if(!hasServerInDB) {
        Format(sqlBuffer, sizeof(sqlBuffer), "INSERT INTO chat_servers (address, sg, disp) VALUES ('%s', -1, '%s');", serverAddress, serverAddress);
        transaction.AddQuery(sqlBuffer, -1337);
    }
    dbChat.Execute(transaction, loadConfigTransactionCallback, threadFailure);
}

public void loadConfigTransactionCallback(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData) {
    
    char tempBuffer[68];
    int tempInt;
    
    clearOrCreateArrayList(chatID, 1);
    clearOrCreateArrayList(chatGroup, 1);
    
    //int tempArray[9];
    clearOrCreateArrayList(chatValid, 9);
    clearOrCreateArrayList(chatDisplay, ByteCountToCells(MAXLENGTH_SQL));
    for(int t = 0; t < MAXTEAMS; t++) {
        for(int s = 0; s < MAXSTATES; s++) {
            clearOrCreateArrayList(chatValue[t][s], ByteCountToCells(MAXLENGTH_SQL));
        }
    }
    clearOrCreateArrayList(flagBits, 1);
    clearOrCreateArrayList(flagGroup, 1);
    
    ArrayList defaultFlags = new ArrayList();
    
    for(int x = 0; x < numQueries; x++) {
        if(queryData[x] >= 0) {
            if(results[x].RowCount) {
                while(results[x].FetchRow()) {
                    chatID.Push(results[x].FetchInt(0));
                    chatGroup.Push(results[x].FetchInt(2));
                    results[x].FetchString(4,  tempBuffer, MAXLENGTH_SQL);
                    chatDisplay.PushString(    tempBuffer);
                    results[x].FetchString(5,  tempBuffer, MAXLENGTH_SQL);
                    chatValue[0][0].PushString(tempBuffer);
                    results[x].FetchString(6,  tempBuffer, MAXLENGTH_SQL);
                    chatValue[0][1].PushString(tempBuffer);
                    results[x].FetchString(7,  tempBuffer, MAXLENGTH_SQL);
                    chatValue[1][0].PushString(tempBuffer);
                    results[x].FetchString(8,  tempBuffer, MAXLENGTH_SQL);
                    chatValue[1][1].PushString(tempBuffer);
                    results[x].FetchString(9,  tempBuffer, MAXLENGTH_SQL);
                    chatValue[2][0].PushString(tempBuffer);
                    results[x].FetchString(10, tempBuffer, MAXLENGTH_SQL);
                    chatValue[2][1].PushString(tempBuffer);
                }
                chatPosition[x] = chatID.Length; //Where to end a loop later on.
            } else {
                chatPosition[x] = -1; //No configs for this exists.
            }
        } else if(queryData[x] == -1) {
            //Flags
            if(results[x].RowCount) {
                while(results[x].FetchRow()) {
                    results[x].FetchString(0, tempBuffer, MAXLENGTH_SQL);
                    //Check if the flag is empty
                    if(!StrEqual(tempBuffer, "", false)) {
                        /*if(StrContains(tempBuffer, ",", false) >= 0) {
                        }*/
                        flagBits.Push(ReadFlagString(tempBuffer));
                        flagGroup.Push(results[x].FetchInt(1));
                    } else {
                        flagBits.Push(0);
                        defaultFlags.Push(flagGroup.Push(results[x].FetchInt(1))); //Shouldn't we just push the group striaght to the ArrayList instead of the index of the group arraylist?
                    }
                }
            }
        }
    }
    
    findDefaultChat(defaultFlags);
    
    dbLoaded = true;
    dbLock = false;
}

public void threadFailure(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData) {
    LogError("Error in Database Execution: %s (%i - #%i)", error, numQueries, failIndex);
}

public void findDefaultChat(ArrayList &defaultFlags) {
    //Search through and find groups with flagbit 0.
    int tempInt;
    //
    for(int d = 0; d < MAXTYPES; d++) {
        for(int i = 0; i < defaultFlags.Length; i++) {
            //Check to see if the top priority is within the group list.
        }
    }
    
    
    
    
    delete defaultFlags;
    defaultFlags = null;
}

public void clearOrCreateArrayList(ArrayList &array, int blocksize) {
    if(array == null) {
        array = new ArrayList(blocksize);
    } else {
        array.Clear();
    }
}

public void deleteArrayList(ArrayList &array) {
    if(array != null) {
        delete array;
        array = null;
    }
}