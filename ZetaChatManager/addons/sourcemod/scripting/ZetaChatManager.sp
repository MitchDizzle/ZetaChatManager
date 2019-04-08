#pragma semicolon 1

#include <clientprefs>
#include <CiderChatProcessor>

#define IN_DEBUG

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
#define CHAT_ALL     CHAT_PREFIX|CHAT_NAME|CHAT_SUFFIX|CHAT_TEXT

//Probably need these for easier lookup later.
int typeKeys[CHAT_MAX] = {
    'p','n','s','t'
};
char typeDisplay[CHAT_MAX][32] = {
    "Prefix","Name","Suffix","Text"
};
int typeBits[CHAT_MAX] = {
    CHAT_PREFIX,CHAT_NAME,CHAT_SUFFIX,CHAT_TEXT
};//Prefix, Name, Suffix, Text

bool plHideChat[MAXPLAYERS+1];
int plChat[MAXPLAYERS+1][CHAT_MAX];
char plSteamId[MAXPLAYERS+1][32];

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
int defaultChat;
int typeValid;

//ArrayList alOrder; //Stores the order shown in the menu.

char defaultValues[CHAT_MAX][2][3][32];

KeyValues kvChat;

ConVar cProfile;

//Cookies!
Handle hChatSettings[CHAT_MAX];
Handle hChatHide;

#define PLUGIN_VERSION "1.0.3"
public Plugin myinfo = {
    name = "Zeta Chat Manager",
    author = "Mitch",
    description = "Zeta Chat Manager",
    version = PLUGIN_VERSION,
    url = "mtch.tech"
};

public void OnPluginStart() {
    CreateConVar("sm_zeta_version", PLUGIN_VERSION, "Zeta Chat Manager Version", FCVAR_DONTRECORD);
    cProfile = CreateConVar("sm_zeta_profile", "", "Current server profile, for multiple separate with comma");
    AutoExecConfig(true, "ZetaChatManager");
    
    RegConsoleCmd("sm_cc", CommandShowChatMenu, "Shows the chat color menu");
    RegConsoleCmd("sm_chatcolor", CommandShowChatMenu, "Shows the chat color menu");
    
    //Register Chat Settings clientprefs.
    char tempBuffer[32];
    hChatHide = RegClientCookie("zeta_hide", "", CookieAccess_Private);
    for(int c = 0; c < CHAT_MAX; c++) {
        Format(tempBuffer, sizeof(tempBuffer), "zeta_%c", typeKeys[c]);
        hChatSettings[c] = RegClientCookie(tempBuffer, "", CookieAccess_Private);
    }
}

public void OnConfigsExecuted() {
    ParseConfig();
}

// When player Connects Load their client prefs.
public void OnClientDisconnect(int client) {
    for(int c = 0; c < CHAT_MAX; c++) {
        //Default it.
        plChat[client][c] = defaultChat;
    }
}

public void OnClientCookiesCached(int client) {
    char sValue[32];
    for(int c = 0; c < CHAT_MAX; c++) {
        GetClientCookie(client, hChatSettings[c], sValue, sizeof(sValue));
        plChat[client][c] = StrEqual(sValue, "") ? defaultChat : LookupChatID(sValue);
    }
    GetClientCookie(client, hChatHide, sValue, sizeof(sValue));
    plHideChat[client] = sValue[0] != '\0' && sValue[0] != '0';
}

public void OnClientPostAdminCheck(int client) {
    if(GetClientAuthId(client, AuthId_Steam2, plSteamId[client], sizeof(plSteamId[]))) {
        //Worked i guess.
    }
}

//CiderChatProcessor part.
public void HandlePlayerColors(int author, char[] name, char[] message, bool overrideMessageColor, ArrayList recipients) {
    bool useDefault = plHideChat[author];
    bool alive = IsPlayerAlive(author);
    int team = GetClientTeam(author);
    if(team < 2) {
        alive = false;
    }
    if(message[0] == '.') {
        //Broadcast to every one in game. (Useful for restricted dead talk)
        int flagBits = GetUserFlagBits(author);
        if(flagBits & ADMFLAG_GENERIC || flagBits & ADMFLAG_ROOT) {
            useDefault = false; //Unhides admin's chat.
            strcopy(message, MAXLENGTH_MESSAGE, message[1]);
            alive = true;
            if(recipients != null) {
                recipients.Clear();
                for(int i = 1; i <= MaxClients; i++) {
                    if(IsClientInGame(i)) {
                        recipients.Push(GetClientUserId(i));
                    }
                }
            }
        }
    }
    char chValue[CHAT_MAX][64];
    int tempIndex = defaultChat;
    for(int c = 0; c < CHAT_MAX; c++) {
        tempIndex = !useDefault && ChatAccess(author, plChat[author][c]) ? plChat[author][c] : defaultChat;
        ChatGetColor(c, tempIndex, alive, team, chValue[c], sizeof(chValue[]));
    }
    //ugly.
    Format(name, MAXLENGTH_NAME, "%s%s%s%s%c", chValue[PREFIX], chValue[NAME], name, chValue[SUFFIX], '\1');
    if(!overrideMessageColor) {
        Format(message, MAXLENGTH_BUFFER, "%s%s", chValue[TEXT], message);
    }
}

public Action CCP_OnChatMessage(int& author, ArrayList recipients, char[] flagstring, char[] name, char[] message) {
    if(author < 0 || author > MaxClients) {
        return Plugin_Continue;
    }
    HandlePlayerColors(author, name, message, false, recipients);
    return Plugin_Changed;
}

public void ChatGetColor(int type, int index, bool alive, int team, char[] buffer, int size) {
    if(index == defaultChat) {
        int a = alive ? 1 : 0;
        int t = team < 2 ? 0 : team-1;
        if(defaultValues[type][a][t][0] == '\0') {
            t = 0;
        }
        if(defaultValues[type][a][t][0] == '\0') {
            a = 1;
        }
        strcopy(buffer, size, defaultValues[type][a][t]);
        return;
    }
    int keyId = alLookup.Get(index, LK_KEYID);
    if(keyId == -1) {
        return;
    }
    kvChat.Rewind();
    if(!kvChat.JumpToKeySymbol(keyId)) {
        LogError("Could not find jump symbol: %i", keyId);
        return;
    }
    char key[4]; int i = 0;
    key[i++] = typeKeys[type];
    if(!alive) {
        key[i++] = 'd';
    }
    if(team > 1) {
        key[i++] = team == 2 ? '2' : '3';
    }
    //Format(key, sizeof(key), "%c%c%c", typeKeys[type], alive ? '' : 'd', team < 2 ? '' : (team == 2 ? '2' : '3')); //First selection
    for(int t = i; t > 0; t--) {
        key[t] = '\0';
        if(kvChat.GetDataType(key) != KvData_None) {
            kvChat.GetString(key, buffer, size, "");
            return;
        }
    }
    return;
}
//Create menus for the preferences
public Action CommandShowChatMenu(int client, int args) {
    if(client) ShowChatMenu(client, -1, 0);
    return Plugin_Handled;
}

public void ShowChatMenu(int client, int type, int page) {
    Menu menu = new Menu(handlerChatMenu);
    char display[64];
    char item[32];
    if(type > -1) {
        int drawStyle = ITEMDRAW_DEFAULT;
        int ciType = -1;
        for(int ci = 0; ci < alLookup.Length; ci++) {
            if(ci != defaultChat) {
                ciType = alLookup.Get(ci, LK_TYPE);
                if(!(ciType & typeBits[type])) {
                    //Config for this isn't the type we're looking for.
                    continue;
                }
                if(!ChatAccess(client, ci)) {
                    // User doesn't have access to this chat type.
                    continue;
                }
                Format(item, sizeof(item), "%i;%i", type, ci);
                drawStyle = plChat[client][type] == ci ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT;
                FormatFromChatIndex(ci, display, sizeof(display));
                menu.AddItem(item, display, drawStyle);
            }
        }
        menu.SetTitle("Chat %s", typeDisplay[type]);
        if(defaultChat != -1) {
            Format(item, sizeof(item), "%i;%i", type, defaultChat);
            drawStyle = plChat[client][type] == defaultChat ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT;
            FormatFromChatIndex(defaultChat, display, sizeof(display));
            if(menu.ItemCount > 0) {
                menu.InsertItem(0, item, display, drawStyle);
            } else {
                menu.AddItem(item, display, drawStyle);
            }
        }
        menu.ExitBackButton = true;
    }
    if(type == -1) {
        menu.SetTitle("Chat Color Settings");
        for(int c = 0; c < CHAT_MAX; c++) {
            Format(item, sizeof(item), "-1;%i", c);
            if(plChat[client][c] > 0) {
                FormatFromChatIndex(plChat[client][c], display, sizeof(display));
                Format(display, sizeof(display), "%s [%s]", typeDisplay[c], display);
            } else {
                Format(display, sizeof(display), "%s", typeDisplay[c]);
            }
            if(c == CHAT_MAX-1) {
                Format(display, sizeof(display), "%s\n ", display);
            }
            menu.AddItem(item, display);
        }
        Format(display, sizeof(display), "%s Chat Colors", plHideChat[client] ? "Show" : "Hide");
        menu.AddItem("-1;-2", display);
        menu.Pagination = 0;
        menu.ExitButton = true;
    }
    menu.DisplayAt(client, page, MENU_TIME_FOREVER);
}

public int handlerChatMenu(Menu menu, MenuAction action, int client, int param2) {
    if(action == MenuAction_End) {
        delete menu;
        return;
    } else if(action == MenuAction_Cancel) {
        if(param2 == MenuCancel_ExitBack) {
            ShowChatMenu(client, -1, 0);
        }
        return;
    } 
    char info[32];
    char tempParts[2][16];
    GetMenuItem(menu, param2, info, sizeof(info));
    if(ExplodeString(info, ";", tempParts, 2, sizeof(tempParts[]), false) != 2) {
        return;
    }
    int type = StringToInt(tempParts[0]);
    int index = StringToInt(tempParts[1]);
    if(type == -1) {
        if(index == -2) {
            plHideChat[client] = !plHideChat[client];
            SetClientCookie(client, hChatHide, plHideChat[client] ? "1" : "0");
        }
        ShowChatMenu(client, index < 0 ? -1 : index, 0);
        return;
    }
    SaveChat(client, type, index); //Updates the plChat and saves the cookie.
    //Display in chat their new color.
    int currTeam = GetClientTeam(client);
    bool alive = IsPlayerAlive(client);
    char chValue[CHAT_MAX][64];
    for(int c = 0; c < CHAT_MAX; c++) {
        ChatGetColor(c, plChat[client][c], alive, currTeam, chValue[c], sizeof(chValue[]));
    }
    PrintToChat(client, "%s%s%N%s\x01: %sTest Text", chValue[PREFIX], chValue[NAME], client, chValue[SUFFIX], chValue[TEXT]);
    ShowChatMenu(client, type, menu.Selection);
}

// Some helper functions to get the current part.
public void FormatFromChatIndex(int index, char[] display, int size) {
    if(index >= 0) {
        int disIndex = alLookup.Get(index, LK_DISPID);
        if(disIndex >= 0 && disIndex < alDisplay.Length) {
            alDisplay.GetString(disIndex, display, size);
            return;
        }
    }
    Format(display, size, "null");
}

public bool ChatAccess(int client, int index) {
    if(index == defaultChat) {
        return true;
    }
    
    int cmdIndex = alLookup.Get(index, LK_OVRDID);
    if(cmdIndex == -1) {
        return true;
    }
    char overrideBuffer[32];
    alOverride.GetString(cmdIndex, overrideBuffer, sizeof(overrideBuffer));
    if(overrideBuffer[0] == '@') {
        //There's no fast way to determine if a client has a group.
        if(!GetCommandOverride(overrideBuffer[1], Override_CommandGroup, index)) {
            GroupId tempGroup = FindAdmGroup(overrideBuffer[1]);
            if(tempGroup != INVALID_GROUP_ID) {
                OverrideRule overrideRule;
                if(!tempGroup.GetCommandOverride(overrideBuffer[1], Override_CommandGroup, overrideRule)) {
                    //Add the group name as an override if it does not exist already.
                    tempGroup.AddCommandOverride(overrideBuffer[1], Override_CommandGroup, Command_Allow);
                }
            }
        }
        //Use check command access for the new override on the group.
        return CheckCommandAccess(client, overrideBuffer[1], ADMFLAG_ROOT, false);
    } else if(overrideBuffer[0] == 'S' &&
              overrideBuffer[4] == 'M' &&
              overrideBuffer[5] == '_' && IsClientAuthorized(client)) { //Probably 'STEAM_'.
        return StrEqual(overrideBuffer, plSteamId[client], false);
    }
    return CheckCommandAccess(client, overrideBuffer, ADMFLAG_ROOT, false);
}

public int LookupChatID(char[] key) {
    int chatId;
    if(!mapKeys.GetValue(key, chatId)) {
        chatId = defaultChat;
    }
    return chatId;
}

public void SaveChat(int client, int type, int index) {
    if(plChat[client][type] == index) {
        //Is already set to index.
        return;
    }
    plChat[client][type] = index;
    char tempBuffer[32] = "";
    ChatGetKey(index, tempBuffer, sizeof(tempBuffer));
    SetClientCookie(client, hChatSettings[type], tempBuffer);
}

public bool ChatGetKey(int index, char[] keyName, int size) {
    if(index < 0 || index >= alLookup.Length) {
        return false;
    }
    int keyId = alLookup.Get(index, LK_KEYID);
    if(keyId < 0) {
        //Couldn't find keyName from index.
        return false;
    }
    kvChat.Rewind();
    if(!kvChat.JumpToKeySymbol(keyId)) {
        LogError("Could not find jump symbol: %i", keyId);
        return false;
    }
    return kvChat.GetSectionName(keyName, size);
}

// Config Loading, as simplified as I could make it..
public void ParseConfig() {
    delete kvChat;
    delete alLookup;
    delete alDisplay;
    delete alOverride;
    delete mapKeys;
    defaultChat = -1;
    
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
        kvLoadProfile(kv, profilePart);
    }
    delete kv; //No longer needed the stored memory.
    delete profiles;
    
    kvStoreBuffers();
    
    //Debug only really..
#if defined IN_DEBUG
    kvChat.Rewind();
    BuildPath(Path_SM, filepath, sizeof(filepath), "configs/zetachatconfig_output.cfg");
    kvChat.ExportToFile(filepath);
#endif
    
    PrintToServer("Loaded %i chat sections", alLookup.Length);
    //CheckPlayers(); //
    if(defaultChat == -1) {
        LogError("Default chat index was not found, make sure the config has a 'default' subsection!");
        return;
    }
    for(int client = 1; client <= MaxClients; client++) {
        for(int c = 0; c < CHAT_MAX; c++) {
            //Default it.
            plChat[client][c] = defaultChat;
        }
        if(IsClientConnected(client) && !IsFakeClient(client)) {
            if(IsClientAuthorized(client)) {
                OnClientPostAdminCheck(client);
            }
            if(AreClientCookiesCached(client)) {
                OnClientCookiesCached(client);
            }
        }
    }
}

public void kvStoreBuffers() {
    //Load references to the Override, Display, KeyID
    kvChat.Rewind();
    if(!kvChat.GotoFirstSubKey()) {
        LogError("Could not go the first subkey (kvChat)!");
        return;
    }
    char keyName[128];
    char buffer[128];
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
    int index = -1;
    bool isDefault = false;
    do {
        //count++;
        kvChat.GetSectionName(keyName, sizeof(keyName));
        isDefault = defaultChat == -1 && StrEqual(keyName, "default", false);
        kvChat.DeleteKey("comment"); //Delete any comments.
        //IntToString(count, buffer, sizeof(buffer));
        //kvChat.SetSectionName(""); // Possbily saves memory to make it smaller. (Actually needed for cookies).
        kvChat.GetString("disp", buffer, sizeof(buffer));
        if(!tmpDisplayMap.GetValue(buffer, lookupData[LK_DISPID])) {
            lookupData[LK_DISPID] = alDisplay.PushString(buffer);
            tmpDisplayMap.SetValue(buffer, lookupData[LK_DISPID], false);
        }
        kvChat.DeleteKey("disp");
        kvChat.GetString("ovrd", buffer, sizeof(buffer), "");
        if(!tmpOverrideMap.GetValue(buffer, lookupData[LK_OVRDID])) {
            if(buffer[0] == '\0') {
                lookupData[LK_OVRDID] = -1;
            } else {
                lookupData[LK_OVRDID] = alOverride.PushString(buffer);
            }
            tmpOverrideMap.SetValue(buffer, lookupData[LK_OVRDID], false);
        }
        kvChat.DeleteKey("ovrd");
        char tempKey[4];
        lookupData[LK_TYPE] = CHAT_NONE;
        for(int c = 0; c < CHAT_MAX; c++) {
            bool foundOne = false;
            for(int a = 0; a <= 1; a++) {
                for(int t = 0; t <= 2; t++) {
                    Format(tempKey, sizeof(tempKey), "%c%c%c", typeKeys[c], a ? "" : "d", t == 1 ? "2" : t == 2 ? "3" : "");
                    kvChat.GetString(tempKey, buffer, sizeof(buffer), "");
                    if(buffer[0] != '\0') {
                        foundOne = true;
                        //Convert any unicode replacements {XX}, {01}/{07} etc.
                        char newBuffer[128];
                        bool replacedAnything = false;
                        for(int pos,npos = 0; pos < strlen(buffer); pos++) {
                            if(buffer[pos] == '\0') {
                                break;
                            }
                            if(buffer[pos] == '{' && buffer[pos+3] == '}') {
                                //We found a variable, copy it nicely.
                                //Try to convert to integer then convert the integer to char.
                                newBuffer[npos++] = (buffer[++pos] - '0') * 10 + (buffer[++pos] - '0');
                                pos++; //Set the post to the ending bracket.
                                replacedAnything = true;
                            } else {
                                newBuffer[npos++] = buffer[pos];
                            }
                        }
                        if(replacedAnything) {
                            //Replaces the old key with the actual unicode character, 4 characters turned to 1.
                            kvChat.SetString(tempKey, newBuffer);
                        }
                        if(isDefault) {
                            //Copy value as default.
                            strcopy(defaultValues[c][a][t], 32, buffer);
                        }
                    }
                }
            }
            if(foundOne) { //Add the bits.
                lookupData[LK_TYPE] |= typeBits[c];
                if(!(typeValid & typeBits[c])) {
                    typeValid = typeValid|typeBits[c];
                }
            }
        }
        //Add keyName to mapKeys & Add lookupData to alLookup
        if(!kvChat.GetSectionSymbol(lookupData[LK_KEYID])) {
            LogError("Invalid KeyID for: '%s'", keyName);
            continue;
        }
        index = alLookup.PushArray(lookupData);
        if(isDefault) {
            //Is default set global var
            defaultChat = index;
        }
        mapKeys.SetValue(keyName, index);
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
        KvCopySubkeys(kv, kvChat);
        kvChat.GoBack();
    } while(kv.GotoNextKey());
}