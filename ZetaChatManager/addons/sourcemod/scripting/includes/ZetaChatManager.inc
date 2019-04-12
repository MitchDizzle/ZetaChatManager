//Zeta Chat Manager include file.

#if defined _ZETACHATMANAGER_included
 #endinput
#endif
#define _ZETACHATMANAGER_included

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


public SharedPlugin __pl_ZetaChatManager = {
	name = "ZetaChatManager",
	file = "ZetaChatManager.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_ZetaChatManager_SetNTVOptional() {
	MarkNativeAsOptional("Zeta_SetDefault");
}
#endif
