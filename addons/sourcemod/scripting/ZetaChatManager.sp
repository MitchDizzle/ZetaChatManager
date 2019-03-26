#pragma semicolon 1

#include <clientprefs>

#define CONFIG_FILE     "configs/zetachatconfig.cfg"

#define PREFIX      0
#define NAME        1
#define SUFFIX      2
#define TEXT        3
#define CHAT_MAX    4

#define CHAT_NONE       0
#define CHAT_PREFIX  (1 << 0)
#define CHAT_NAME    (1 << 1)
#define CHAT_SUFFIX  (1 << 2)
#define CHAT_TEXT    (1 << 3)

//Probably need these for easier lookup later.
char typeKeys[CHAT_MAX][12] = {
    "p","n","s","t"
};
int typeBits[CHAT_MAX] = {
    CHAT_PREFIX,CHAT_NAME,CHAT_SUFFIX,CHAT_TEXT
};//Prefix, Name, Suffix, Text

int plChat[MAXPLAYERS+1][CHAT_MAX];

#define LK_TYPE   0
#define LK_KEYID  1
#define LK_DISPID 2
#define LK_OVRDID 3
#define LK_MAX    4
//Contains:
//int  type //Stores if the entry has Prefix, Name, Suffix, or Text within the config.
//int  KeyID
//int  DisplayID
//int  OverrideID
ArrayList alLookup;
ArrayList alDisplay;
ArrayList alOverride;
StringMap mapKeys;

KeyValues kvChat;

ConVar cProfile;

//Cookies!
Handle hChatSettings[CHAT_MAX];

#define PLUGIN_VERSION "1.0.0"
public Plugin myinfo = {
    name = "Zeta Chat Manager",
    author = "Mitch",
    description = "Zeta Chat Manager",
    version = PLUGIN_VERSION,
    url = "mtch.tech"
};

public void OnPluginStart() {
    cProfile = CreateConVar("sm_zeta_profile", "Murder,One,Two,Three,Four,Five,Sizeassdsd,FSuasydiu", "Current server profile, for multiple separate with comma");
    AutoExecConfig();
    
    //Register Chat Settings clientprefs.
    char tempBuffer[32];
    for(int c = 0; c < CHAT_MAX; c++) {
        Format(tempBuffer, sizeof(tempBuffer), "zeta_%s", typeKeys[c]);
        hChatSettings[c] = RegClientCookie(tempBuffer, "", CookieAccess_Private);
    }
}

public void OnConfigsExecuted() {
    ParseConfig();
}

// When player Connects Load their client prefs.



//When players sends a message replace it with the better ones.








// Some helper functions to get the current part.
public void chatGetPlayerValues(int client, char chatValues[CHAT_MAX]) {
    
    
    
    for(int c = 0; c < CHAT_MAX; c++) {
        
        
        
    }
}

public void chatGetValue(KeyValues kv, int type, char[] chatValue) {
    
}

// Config Loading, as simplified as I could make it..
public void ParseConfig() {
    delete kvChat;
    delete alLookup;
    delete alDisplay;
    delete alOverride;
    delete mapKeys;
    
    //Parse Profile first to get list of profiles.
    char profileBuffer[512];
    cProfile.GetString(profileBuffer, sizeof(profileBuffer));
    TrimString(profileBuffer);
    ArrayList profiles = new ArrayList(ByteCountToCells(32));
    char profilePart[32];
    int strLength = strlen(profileBuffer);
    for(int bufferPos = 0; bufferPos < strLength;) {
        int tempPos = StrContains(profileBuffer[bufferPos], ",", false);
        if(tempPos == -1) {
            tempPos = strLength;
        }
        strcopy(profilePart, tempPos+1, profileBuffer[bufferPos]);
        bufferPos += tempPos+1;
        TrimString(profilePart);
        if(strlen(profilePart) > 0) {
            profiles.PushString(profilePart);
        }
    }
    
    KeyValues kv = CreateKeyValues("ZetaChatConfig");
    char filepath[256];
    BuildPath(Path_SM, filepath, sizeof(filepath), CONFIG_FILE);

    // Load KV from File
    if(!kv.ImportFromFile(filepath)) {
        delete kv;
        SetFailState("Cannot find file \"%s\"!", filepath);
    }
    profiles.PushString("default");
    kvChat = CreateKeyValues("");
    for(int i = 0; i < profiles.Length; i++) {
        profiles.GetString(i, profilePart, sizeof(profilePart));
        //PrintToServer("%i - %s", i, profilePart);
        kvLoadProfile(kv, profilePart);
    }
    delete kv; //No longer needed the stored memory.
    delete profiles;
    
    kvStoreBuffers();
    
    //Debug only really..
    kvChat.Rewind();
    BuildPath(Path_SM, filepath, sizeof(filepath), "configs/zetachatconfig_output.cfg");
    kvChat.ExportToFile(filepath);
    
    PrintToServer("Loaded %i chat sections", alLookup.Length);
    //CheckPlayers(); //
    
}

public void kvStoreBuffers() {
    //Load references to the Override, Display, KeyID
    kvChat.Rewind();
    if(!kvChat.GotoFirstSubKey()) {
        LogError("Could not go the first subkey (kvChat)!");
        return;
    }
    char keyName[64];
    char buffer[64];
    any lookupData[LK_MAX] = {
        0,  //LK_TYPE
        -1, //LK_KEYID
        -1, //LK_DISPID
        -1  //LK_OVRDID
    };
    alLookup = new ArrayList(LK_MAX);
    alDisplay = new ArrayList(ByteCountToCells(32));
    alOverride = new ArrayList(ByteCountToCells(32));
    mapKeys = new StringMap();
    
    StringMap tmpDisplayMap = new StringMap();
    StringMap tmpOverrideMap = new StringMap();
    int count = 0;
    do {
        count++;
        kvChat.GetSectionName(keyName, sizeof(keyName));
        if(!kvChat.GetSectionSymbol(lookupData[LK_KEYID])) {
            LogError("Invalid KeyID for: '%s'", keyName);
            continue;
        }
        IntToString(count, buffer, sizeof(buffer));
        kvChat.SetSectionName(buffer); // Possbily saves memory to make it smaller.
        kvChat.GetString("disp", buffer, sizeof(buffer));
        if(!tmpDisplayMap.GetValue(buffer, lookupData[LK_DISPID])) {
            lookupData[LK_DISPID] = alDisplay.PushString(buffer);
            tmpDisplayMap.SetValue(buffer, lookupData[LK_DISPID], false);
            //PrintToServer("Adding Display: [%i] %s", lookupData[LK_DISPID], buffer);
        }
        kvChat.DeleteKey("disp");
        kvChat.GetString("ovrd", buffer, sizeof(buffer));
        if(!tmpOverrideMap.GetValue(buffer, lookupData[LK_OVRDID])) {
            lookupData[LK_OVRDID] = alOverride.PushString(buffer);
            tmpOverrideMap.SetValue(buffer, lookupData[LK_OVRDID], false);
            //PrintToServer("Adding Override: [%i] %s", lookupData[LK_OVRDID], buffer);
        }
        kvChat.DeleteKey("ovrd");
        char tempKey[4];
        lookupData[LK_TYPE] = CHAT_NONE;
        for(int c = 0; c < CHAT_MAX; c++) {
            bool foundOne = false;
            for(int a = 0; a <= 1; a++) {
                for(int t = 1; t <= 3; t++) {
                    Format(tempKey, sizeof(tempKey), "%c%c%c", typeKeys[c], a ? "d" : "", t == 2 ? "2" : t == 3 ? "3" : "");
                    kvChat.GetString(tempKey, buffer, sizeof(buffer), "");
                    if(buffer[0] != '\0') {
                        foundOne = true;
                        //Restore it with the {07} replaced?
                        if(ReplaceString(buffer, sizeof(buffer), "{07}", "\x07") > 0) {
                            //Replaces the old key with the actual unicode character, 4 characters turned to 1.
                            kvChat.SetString(tempKey, buffer);
                            kvChat.GetString(tempKey, buffer, sizeof(buffer));
                            PrintToServer("%s: %s", tempKey, buffer);
                        }
                    }
                }
            }
            if(foundOne) { //Add the bits.
                lookupData[LK_TYPE] |= typeBits[c];
            }
        }
        //PrintToServer("%s - %i (%i): %i", keyName, lookupData[LK_DISPID], lookupData[LK_OVRDID], lookupData[LK_TYPE]);
        //Add keyName to mapKeys & Add lookupData to alLookup
        mapKeys.SetValue(keyName, alLookup.PushArray(lookupData));
    } while(kvChat.GotoNextKey());
    delete tmpDisplayMap;
    delete tmpOverrideMap;
}

public void kvLoadProfile(KeyValues kv, char[] profile) {
    kv.Rewind();
    kvChat.Rewind();
    if(!kv.JumpToKey(profile, false)) {
        LogError("Profile not found in config! '%s'", profile);
        return;
    }
    if(!kv.GotoFirstSubKey()) {
        LogError("Could not go into profiles sub keys! '%s'", profile);
        return;
    }
    char keyName[64];
    do {
        KvGetSectionName(kv, keyName, sizeof(keyName));
        if(kvChat.JumpToKey(keyName, false)) {
            //Subsection already exists, and we don't override.
            kvChat.GoBack();
            continue;
        }
        //Key does not exist in kvChat, let's add it. seems weird but what evs.
        if(!kvChat.JumpToKey(keyName, true)) {
            LogError("Unable to copy subsection '%s' into local config.", keyName);
            continue;
        }
        //PrintToServer("Appending %s", keyName);
        KvCopySubkeys(kv, kvChat);
        kvChat.GoBack();
    } while(kv.GotoNextKey());
}