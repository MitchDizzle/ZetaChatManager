#pragma semicolon 1

#include <sdktools>
#include <clientprefs>
#include <CiderChatProcessor>

#define PLUGIN_VERSION "1.0.0"
#define MAXCHATCOLORS 20
#define ALIVE 0
#define DEAD 1

#define CHAT_PREFIX  (1 << 0)
#define CHAT_NAME    (1 << 2)
#define CHAT_SUFFIX  (1 << 1)
#define CHAT_TEXT    (1 << 3)
#define MAXTYPES  4
#define MAXTEAMS  3
#define MAXSTATES 2
#define MAXLENGTH 64
char defaultChat[MAXTYPES][MAXTEAMS][MAXSTATES][MAXLENGTH];

/*
char chatID[MAXCHATCOLORS][32];
char chatDisplay[MAXCHATCOLORS][32];
char chatAccess[MAXCHATCOLORS][MAXLENGTH];
int chatAccessType[MAXCHATCOLORS]; //0 Flag, 1 - Steam
char chatName[MAXCHATCOLORS][MAXSTATES][MAXLENGTH];
char chatText[MAXCHATCOLORS][MAXSTATES][MAXLENGTH];
char chatPrefix[MAXCHATCOLORS][MAXSTATES][MAXLENGTH];
char chatSuffix[MAXCHATCOLORS][MAXSTATES][MAXLENGTH];
int maxChatConfig;
StringMap idLookup;
*/

int plySel[MAXPLAYERS+1][MAXTYPES];
Handle cChat[4];

Database db;


public Plugin myinfo = {
    name = "Zeta Chat Manager",
    author = "Mitch",
    description = "Zeta Chat Manager",
    version = PLUGIN_VERSION,
    url = "mtch.tech"
};

public OnPluginStart() {
    cChat[0] = RegClientCookie("zcm_prefix", "Enable Prefix", CookieAccess_Private);
    cChat[1] = RegClientCookie("zcm_name", "Enable Name Color", CookieAccess_Private);
    cChat[2] = RegClientCookie("zcm_suffix", "Enable Suffix", CookieAccess_Private);
    cChat[3] = RegClientCookie("zcm_text", "Enable Text Color", CookieAccess_Private);
    
    RegAdminCmd("sm_chatcolor", Command_Chat, 0);
    RegAdminCmd("sm_cc", Command_Chat, 0);
    RegAdminCmd("sm_default", Command_Default, 0);
    
    loadConfig();

    for(int i = 1; i <= MaxClients; i++) {
        plySel[i][0] = -2;
        plySel[i][1] = -2;
        plySel[i][2] = -2;
        plySel[i][3] = -2;
        if(IsClientInGame(i)) {
            if(AreClientCookiesCached(i)) {
                OnClientCookiesCached(i);
            }
        }
    }
}

public void OnClientDisconnect(int client) {
    plySel[client][0] = -2;
    plySel[client][1] = -2;
    plySel[client][2] = -2;
    plySel[client][3] = -2;
}

public void OnClientCookiesCached(int client) {
    char sValue[64];
    
    for(int c = 0; c < 4; c++) {
        GetClientCookie(client, cChat[c], sValue, sizeof(sValue));
        plySel[client][c] = StrEqual(sValue, "") ? -2 : getChatFromID(sValue);
    }
    pickChatColor(client);
}

public void HandlePlayerColors(int author, char[] name, char[] message, bool overrideMessageColor) {
    bool alive = IsPlayerAlive(author);
    int team = GetClientTeam(author);
    if(team < 2) {
        alive = false;
    } 
    int flagBits = GetUserFlagBits(author);
    bool plyIsAdmin = (flagBits & ADMFLAG_ROOT || flagBits & ADMFLAG_GENERIC);
    if(!alive && plyIsAdmin && StrContains(message, ".") == 0) {
        ReplaceStringEx(message, MAXLENGTH_MESSAGE, ".", "", 1, 0, false);
        alive = true;
    }
    int alv = alive ? 0 : 1;
    char chValue[4][64];
    
    int ch = 0;
    for(int c = 0; c < 4; c++) {
        ch = plySel[author][c];
        if(ch < 0) {
            //Use Defaults
            Format(chValue[c], 64, "%s", defaultChat[c][alv]);
        } else {
            if(c == 0) {
                Format(chValue[c], 64, "%s", chatName[ch][alv]);
            } else if(c == 1) {
                Format(chValue[c], 64, "%s", chatText[ch][alv]);
            } else if(c == 2) {
                Format(chValue[c], 64, "%s", chatPrefix[ch][alv]);
            } else if(c == 3) {
                Format(chValue[c], 64, "%s", chatSuffix[ch][alv]);
            }
        }
    }
    Format(name, MAXLENGTH_NAME, "%s%s%s%s\x01", chValue[2], chValue[0], name, chValue[3]);
    if(!overrideMessageColor) {
        Format(message, MAXLENGTH_BUFFER, "%s%s", chValue[1], message);
    }
}


public Action CCP_OnChatMessage(int& author, ArrayList recipients, char[] flagstring, char[] name, char[] message) {
    if(author < 0 || author > MaxClients) {
        return Plugin_Continue;
    }
    HandlePlayerColors(author, name, message, false);
    return Plugin_Changed;
}

public void pickChatColor(int client) {
    if(plySel[client][0] != -2 ||
        plySel[client][1] != -2 ||
        plySel[client][2] != -2 ||
        plySel[client][3] != -2) {
        return;
    } //Player should lookup new chat config.
    char authId[48];
    if(!GetClientAuthId(client, AuthId_Steam2, authId, sizeof(authId), true)) {
        return;
    }
    int flagBits = 0;
    int userBits = GetUserFlagBits(client);
    for(int s = 0; s < 4; s++) {
        plySel[client][s] = -1;
        for(int c = 0; c < maxChatConfig; c++) {
            if(s == 0 && StrEqual(chatName[c][0], defaultChat[s][0]) && StrEqual(chatName[c][1], defaultChat[s][1])) {
                continue;
            } if(s == 1 && StrEqual(chatText[c][0], defaultChat[s][0]) && StrEqual(chatText[c][1], defaultChat[s][1])) {
                continue;
            } if(s == 2 && StrEqual(chatPrefix[c][0], defaultChat[s][0]) && StrEqual(chatPrefix[c][1], defaultChat[s][1])) {
                continue;
            } if(s == 3 && StrEqual(chatSuffix[c][0], defaultChat[s][0]) && StrEqual(chatSuffix[c][1], defaultChat[s][1])) {
                continue;
            }
            //Check the auth type of this chat config
            if(chatAccessType[c] == 0) {
                //By Flag
                flagBits = ReadFlagString(chatAccess[c]);
                if(userBits & flagBits) {
                    plySel[client][s] = c;
                    SetClientCookie(client, cChat[s], chatID[c]);
                    break;
                }
            } else if(StrEqual(authId, chatAccess[c], false)) {
                //By Steam
                plySel[client][s] = c;
                SetClientCookie(client, cChat[s], chatID[c]);
                break;
            }
        }
    }
}

public int getChatFromID(char[] chatId) {
    int value = -1;
    idLookup.GetValue(chatId, value);
    return value;
}

public Action Command_Chat(int client, int args) {
    displayMainMenu(client);
    return Plugin_Handled;
}

public Action Command_Default(int client, int args) {
    //plyChat[client] = -2;
    //SetClientCookie(client, cID, "");
    return Plugin_Handled;
}

public void displayMainMenu(int client) {
    if(!client) {
        return;
    }
    char cat[4][32] = {
        "Name",
        "Text",
        "Prefix",
        "Suffix"
    };
    char info[12];
    char display[255];
    Menu menu = new Menu(Menu_Main, MENU_ACTIONS_DEFAULT);
    menu.SetTitle("Chat Menu:");
    for(int c = 0; c < 4; c++) {
        
        Format(display, sizeof(display), "%s: ", cat[c]);
        if(plySel[client][c] < 0) {
            Format(display, sizeof(display), "%sDefault", display);
        } else {
            Format(display, sizeof(display), "%s%s", display, chatDisplay[plySel[client][c]]);
        }
        IntToString(c, info, sizeof(info));
        menu.AddItem(info, display);
    }
    menu.Pagination = MENU_NO_PAGINATION;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public Menu_Main(Menu menu, MenuAction action, int client, int param2) {
    switch (action)    {
        case MenuAction_End:
            delete menu;
        case MenuAction_Select: {
            char info[12];
            GetMenuItem(menu, param2, info, sizeof(info));
            displayChatMenu(client, StringToInt(info), 0);
        }
    }
    return;
}

int menuSel[MAXPLAYERS+1];
public void displayChatMenu(int client, int chat, int page) {
    if(!client) {
        return;
    }
    menuSel[client] = chat;
    char authId[48];
    char authIdLower[48];
    if(!GetClientAuthId(client, AuthId_Steam2, authId, sizeof(authId), true)) {
        return;
    }
    StrToLowerRemoveBlanks(authIdLower, authId, sizeof(authId));
    int ch = plySel[client][chat];
    
    Menu menu = new Menu(Menu_Chat, MENU_ACTIONS_DEFAULT);
    menu.SetTitle("Select Setup:");
    menu.AddItem("default", "Default", ch == -1 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
    int flagBits = 0;
    int userBits = GetUserFlagBits(client);
    for(int c = 0; c < maxChatConfig; c++) {
        //Check the auth type of this chat config
        
        if(c != ch) {
            if(chat == 0 && StrEqual(chatName[c][0], defaultChat[chat][0]) && StrEqual(chatName[c][1], defaultChat[chat][1])) {
                continue;
            } if(chat == 1 && StrEqual(chatText[c][0], defaultChat[chat][0]) && StrEqual(chatText[c][1], defaultChat[chat][1])) {
                continue;
            } if(chat == 2 && StrEqual(chatPrefix[c][0], defaultChat[chat][0]) && StrEqual(chatPrefix[c][1], defaultChat[chat][1])) {
                continue;
            } if(chat == 3 && StrEqual(chatSuffix[c][0], defaultChat[chat][0]) && StrEqual(chatSuffix[c][1], defaultChat[chat][1])) {
                continue;
            }
        }
        
        if(chatAccessType[c] == 0) {
            //By Flag
            flagBits = ReadFlagString(chatAccess[c]);
            if(!(userBits & flagBits)) {
                //Player does not contain flags
                continue;
            }
        } else if(!StrEqual(authIdLower, chatAccess[c], false)) {
            //Steamids do not match
            continue;
        }
        menu.AddItem(chatID[c], chatDisplay[c], ch == c ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
    }
    menu.ExitButton = true;
    menu.DisplayAt(client, page, MENU_TIME_FOREVER);
}

public Menu_Chat(Menu menu, MenuAction action, int client, int param2) {
    switch (action)    {
        case MenuAction_End:
            delete menu;
        case MenuAction_Cancel:
            displayMainMenu(client);
        case MenuAction_Select: {
            char info[32];
            GetMenuItem(menu, param2, info, sizeof(info));
            int ch = menuSel[client];
            plySel[client][ch] = getChatFromID(info);
            SetClientCookie(client, cChat[ch], info);
            displayChatMenu(client, ch, menu.Selection);
            
            char chValue[4][64];
            for(int a = 0; a < 2; a++) {
                for(int c = 0; c < 4; c++) {
                    ch = plySel[client][c];
                    if(ch < 0) {
                        //Use Defaults
                        Format(chValue[c], 64, "%s", defaultChat[c][a]);
                    } else {
                        if(c == 0) {
                            Format(chValue[c], 64, "%s", chatName[ch][a]);
                        } else if(c == 1) {
                            Format(chValue[c], 64, "%s", chatText[ch][a]);
                        } else if(c == 2) {
                            Format(chValue[c], 64, "%s", chatPrefix[ch][a]);
                        } else if(c == 3) {
                            Format(chValue[c], 64, "%s", chatSuffix[ch][a]);
                        }
                    }
                }
                PrintToChat(client, "\x01%s%s%N%s\x01: %sPreview of %s text.", chValue[2], chValue[0], client, chValue[3], chValue[1], a == 0 ? "alive" : "dead");
            }
        }
    }
    return;
}

stock void kvGetStringColor(KeyValues kv, const char[] key, char[] value, int maxlength, const char[] defvalue="") {
    kv.GetString(key, value, maxlength, defvalue);
    ReplaceString(value, maxlength, "{07}", "\x07");
}

stock int StrToLowerRemoveBlanks(const char[] str, char[] buffer, int bufsize) {
    int n = 0;
    int x = 0;
    while (str[n] != '\0' && x < (bufsize-1)) { // Make sure we are inside bounds
        int charac = str[n++];
        if (charac == ' ') {
            continue;
        }else if (IsCharUpper(charac)) {
            charac = CharToLower(charac);
        }
        buffer[x++] = charac;
    }
    buffer[x++] = '\0';
    return x;
}

public int Native_FakeSay(Handle plugin, int args) {
    int client = GetNativeCell(1);
    if(!NativeCheck_IsClientValid(client)) {
        return false;
    }
    char message[MAXLENGTH_MESSAGE];
    GetNativeString(2, message, MAXLENGTH_MESSAGE);
    fakeSayEx(client, message, "");
    return true;
}

public int Native_FakeSayEx(Handle plugin, int args) {
    int client = GetNativeCell(1);
    if(!NativeCheck_IsClientValid(client)) {
        return false;
    }
    char message[MAXLENGTH_MESSAGE];
    char textColor[32];
    GetNativeString(2, message, MAXLENGTH_MESSAGE);
    GetNativeString(3, textColor, 32);
    fakeSayEx(client, message, textColor);
    return true;
}

public void fakeSayEx(int client, char[] message, char[] textColor) {
    char name[MAXLENGTH_MESSAGE];
    GetClientName(client, name, sizeof(name));
    //CCP_HandleRecipients(client, recipients, "")
    HandlePlayerColors(client, name, message, true);
    char messageBuffer[256];
    Format(messageBuffer, sizeof(messageBuffer), "%s\x01: %s%s", name, textColor, message);
    PrintToChatAll(messageBuffer);
}

stock bool NativeCheck_IsClientValid(int client) {
    if(client <= 0 || client > MaxClients) {
        ThrowNativeError(SP_ERROR_NATIVE, "Client index %i is invalid", client);
        return false;
    }
    if(!IsClientInGame(client)) {
        ThrowNativeError(SP_ERROR_NATIVE, "Client %i is not in game", client);
        return false;
    }
    return true;
}