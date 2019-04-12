# Zeta Chat Manager

An enhanced chat color plugin that allows clients be flexible about their chat's prefix, prefix+color, name color, suffix+color and text color. Requires Cider-Chat-Processor, Chat Processor. (Or god forbid simple-chatprocessor).

### This works well with GroupHandlerAPI, but isn't required.

Don't expect this to be easier to setup than custom-chat-colors plugin, this is more advanced for a reason. It allows players to toggle on and off certain aspects of their tags and choose tags that the server operator allows them to have. 

*This currently does not allow players to adjust the colors of their tags but it is planned later.*

For any issues post in the Alliedmods forum or create GitHub issue marking what's wrong and any information to help solve your issue faster.
Contributions are welcome via PR, however my code style will not change (4 space indent, brackets on the same line as the condition, and no one line statements).

# Server config

## Profiles
The config can be the same on multiple server and have different results depending on what server loads the config. Using profiles to apply more chat sections or override existing ones.
```
// Each Profile is separated with commons, ex: sm_zeta_profile "Murder,FF2,Test Server"
sm_zeta_profile ""
```

## zetachatconfig.cfg
It's not recommend to use this one this just goes over the basic of each value.
```
//To save space after the config is loaded into memory make sure any blank KeyValues are commented out or removed.
"ZetaChatConfig"
{
    "default"
    {//Default group which contains the config for all the servers.
        "default" //Unique ID, used when saving in in client prefs.
        { // 'default' is the chat tag that will be specificall used for all players until they use the command to change it.
            "n"   "{03}" //Name color (This is also used for Spectators.)
            "nd"    "" //Name color while dead.
            "n2"    "" //Name color for team 2 (RED) (Blank will fallback to the normal "n" etc)
            "nd2"   "" //Name color for team 2 (RED) while dead (Falls back to "nd" etc.)
            "n3"    "" //Name color for team 2 (BLU)
            "nd3"   "" //Name color for team 2 (BLU) while dead
            
            //All of these also have team specific colors just add '2' or '3' to the end of the key.
            "t"     "" //Text color
            "td"    "" //Text color while dead

            "p"     "" //Prefix
            "pd"    "" //Prefix while dead

            "s"     "" //Suffix
            "sd"    "" //Suffix while dead

            //Name, Text, Prefix and Suffix are all saved in client prefs as individual values.
            //  The option in the menu will only display if there is a value set.
            //  This default section will always display in the menu to allow players to unset their tags.
            
            //Access Identifiers.
            //Checks to see if the player has access to this override. RECOMMENDED way of determining if a user has access to this section. 
            //You can use command overrides to give users access to this command, overrides can be group based also.
            "ovrd" ""
            // Can also be STEAM_XXXX or "@Group Name", these are not recommended if you're defining more than one section for a certain person/group.
            // GroupHandlerAPI and GroupAssigner is great for giving players a certain group, even if it doesn't exist in admin_groups.cfg!
            //   GroupHandlerAPI will automatically assign the group to have the override of the same name of the group. i.e. "Badass Admins" group name will have the override "Badass Admins" added to it.

            "disp" "Default" //The display that shows in the menu and when you equip it. Doesn't have to be unique, so you can have multiple that have the same display.
        }
    }
    "Server 1"
    {//Server profile, anything within this profile will blend into the default group. 
     // Depending on the convar, the profile will load first, then the next. Default profile is loaded last.
     // Duplicate enteries will use the top level one, i.e. does not override.
        "default"
        { //Sets default name for alive and dead.
            "n"     "{07}cccccc"
            "nd"    "{07}999999"
            "disp"  "Default"
        }
    }
}
```

# Developers

There are some natives to set the default tag, I couldn't figure out a way to assign a player a certain tag via this plugin.
For an example I wanted to give a suffix to vips, however Zeta doesn't know when a player might get access to that group. The plugin that takes advantage of GroupHandlerAPI also uses this native to set the player's default to the correct value. The native won't override their clientprefs if they already have one that isn't blank. You can also use it to unset their tag etc by passing in blank.

**ZetaChatManager.inc**
```
#define ZETACHAT_NONE       0
#define ZETACHAT_PREFIX  (1 << 0)
#define ZETACHAT_NAME    (1 << 1)
#define ZETACHAT_SUFFIX  (1 << 2)
#define ZETACHAT_TEXT    (1 << 3)
#define ZETACHAT_ALL     ZETACHAT_PREFIX|ZETACHAT_NAME|ZETACHAT_SUFFIX|ZETACHAT_TEXT

/**
 * Sets the default chat of the player
 * typeBits is ZETACHAT_* defines above.
 * Should only be used if the clientprefs are already cached for the player.
 */
native bool Zeta_SetDefault(int client, int typeBits, char[] chatKey);
```