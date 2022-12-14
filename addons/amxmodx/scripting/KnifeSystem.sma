/* Plugin generated by AMXX-Studio */

#include < amxmodx >
#include < engine >
#include < fakemeta >
#include < fun >
#include < hamsandwich >

#define IS_PLAYER(%0) ( 0 < ( %0 ) < MaxClients )
//#define SQL

#if defined SQL
	#include < sqlx >
	new const g_sSQL_INFOS[ ][ ] =
	{
		"127.0.0.1",
		"USERNAME",
		"PASSWORD",
		"DATABASE",
	}
	new Handle:g_iSqlTuple;
#else
	#include < nvault >
	new const g_sNVAULTNAME[ ] = "PlayerDatas";
	new g_iNvaultId;
#endif

enum _:ePlayerInfos
{
	iPlayerLvl,
	iPlayerXp,
	iPlayerPoints,
	iPlayerSelected
};

new const g_sPLUGIN[ ] = "KnifeSystem";
new const g_sVERSION[ ] = "v2";
new const g_sAUTHOR[ ] = "Akosch:.";
new const g_sPREFIX[ ] = "[A:.]";

const g_iADD_FLAG = ADMIN_CVAR;

new Array:g_daKnives[ 10 ], Array:g_daLevels, Array:g_daItemName;
new Array:g_daItemCost, Array:g_daItemFuncId, Array:g_daItemPluginId, g_pCvars[ 6 ];
new g_iPlayerInfos[ MAX_PLAYERS + 1 ][ ePlayerInfos ], g_iTarget[ MAX_PLAYERS + 1 ];
new g_sPlayerName[ MAX_PLAYERS + 1 ][ MAX_NAME_LENGTH ], g_iForwards[ 3 ], g_iMap;

public plugin_natives( )
{
	register_native( "ks_register_item", "@naRegItem" );
	register_native( "ks_get_player_info", "@naGetPlayerInfo" );
	register_native( "ks_get_knife_info", "@naGetKnifeInfo" );
	register_native( "ks_get_max_level", "@naGetMaxLvl" );
}

public plugin_init( )
{
	RegisterHam( Ham_CS_Player_ResetMaxSpeed, "player", "@fwResetMaxSpeedPost", 1, true );
	RegisterHam( Ham_Item_Deploy, "weapon_knife", "@fwWeaponKnifePost", 1, true );
	RegisterHam( Ham_TakeDamage, "player", "@fwTakeDamagePre", 0, true );
	RegisterHam( Ham_Spawn, "player", "@fwPlayerSpawnPost", 1, true );

	register_message( get_user_msgid( "Health" ), "@msgHealth" );

	register_event( "DeathMsg", "@evDeath", "a" );

	register_clcmd( "drop", "@fnShowMenu" );
	register_clcmd( "say /menu", "@fnShowMenu" );
	register_clcmd( "GIFT", "@fnGiftHandler" );
	register_clcmd( "ADD", "@fnAddHandler" );

	g_iForwards[ 0 ] = CreateMultiForward( "ks_level_up", ET_IGNORE, FP_CELL, FP_CELL );
	g_iForwards[ 1 ] = CreateMultiForward( "ks_max_lvl_reached", ET_IGNORE, FP_CELL );
	g_iForwards[ 2 ] = CreateMultiForward( "ks_knife_selected", ET_IGNORE, FP_CELL, FP_CELL );

	g_pCvars[ 0 ] = register_cvar( "kill_msgs", "0" );
	g_pCvars[ 1 ] = register_cvar( "kill_xp", "1" );
	g_pCvars[ 2 ] = register_cvar( "kill_point", "1" );
	g_pCvars[ 3 ] = register_cvar( "hs_xp", "3" );
	g_pCvars[ 4 ] = register_cvar( "hs_point", "2" );
	
	new sMapName[ 32 ];
	get_mapname( sMapName, charsmax( sMapName ) );

	if ( equal( sMapName, "1hp", 3 ) )
		g_iMap = 1;
	else if ( equal( sMapName, "35hp", 4 ) )
		g_iMap = 35;
	else
		g_iMap = 100;

#if defined SQL
	g_iSqlTuple = SQL_MakeDbTuple( g_sSQL_INFOS[ 0 ], g_sSQL_INFOS[ 1 ], g_sSQL_INFOS[ 2 ], g_sSQL_INFOS[ 3 ] );

	new sThread[ 256 ];
	formatex( sThread, charsmax( sThread ), "CREATE TABLE IF NOT EXISTS `KnifeSystem` (`SteamId` varchar( 32 ) NOT NULL, `Level` INT( 11 ) NOT NULL, `Xp` INT( 11 ) NOT NULL, `Points` INT( 11 ) NOT NULL, `Selected` INT( 11 ) NOT NULL, `id` INT( 11 ) NOT NULL AUTO_INCREMENT PRIMARY KEY )" );

	SQL_ThreadQuery( g_iSqlTuple, "@fnThreadHandler", sThread );
#else
	g_iNvaultId = nvault_open( g_sNVAULTNAME );
	
	if ( g_iNvaultId == INVALID_HANDLE )
		set_fail_state( "%L", LANG_SERVER, "INVALIDNVAULTID" )
#endif
}

public plugin_precache( )
{
	register_dictionary( "KnifeSystem.txt" );
	register_plugin( g_sPLUGIN, g_sVERSION, g_sAUTHOR );

	g_daKnives[ 0 ] = ArrayCreate( 32 );
	g_daKnives[ 1 ] = ArrayCreate( 32 );
	g_daKnives[ 2 ] = ArrayCreate( 32 );
	g_daKnives[ 3 ] = ArrayCreate( 1 );
	g_daKnives[ 4 ] = ArrayCreate( 1 );
	g_daKnives[ 5 ] = ArrayCreate( 1 );
	g_daKnives[ 6 ] = ArrayCreate( 1 );
	g_daKnives[ 7 ] = ArrayCreate( 1 );
	g_daKnives[ 8 ] = ArrayCreate( 1 );
	g_daKnives[ 9 ] = ArrayCreate( 1 );

	g_daItemName = ArrayCreate( 32 );
	g_daItemFuncId = ArrayCreate( 1 );
	g_daItemCost = ArrayCreate( 1 );
	g_daItemPluginId = ArrayCreate( 1 );

	g_daLevels = ArrayCreate( 1 );

	new sBuffer[ 128 ], sFile[ 64 ], pFile;
	get_localinfo( "amxx_configsdir", sFile, charsmax( sFile ) );
	add( sFile, charsmax( sFile ), "/knives.txt" );

	pFile = fopen( sFile, "rt" );

	if ( pFile )
	{
		new sKey[ 64 ], sValue[ 64 ], sKEYS[ sizeof( g_daKnives ) ][ 32 ];
		new iSize, iSize2, i;

		for ( i = 1; i < sizeof( sKEYS ); ++i )
		{
			formatex( sKEYS[ i ], charsmax( sKEYS[ ] ), "KEY%i", i );
			formatex( sKEYS[ i ], charsmax( sKEYS[ ] ), "%L", LANG_SERVER, sKEYS[ i ] );
		}
		
		while ( !feof( pFile ) )
		{
			fgets( pFile, sBuffer, charsmax( sBuffer ) );
			trim( sBuffer );
			
			if ( sBuffer[ 0 ] == '/' || sBuffer[ 0 ] == ';' || !sBuffer[ 0 ] )
				continue;
			
			if ( sBuffer[ 0 ] == '[' )
			{
				iSize = ArraySize( g_daKnives[ 0 ] );

				for ( i = 1; i < sizeof ( g_daKnives ); ++i )
				{
					iSize2 = ArraySize( g_daKnives[ i ] );
					
					switch ( i )
					{
						case 1:
							while ( iSize2 < iSize )
							{
								ArrayPushString( g_daKnives[ 1 ], "models/v_knife.mdl" );
								++iSize2;
							}
						case 2:
							while ( iSize2 < iSize )
							{
								ArrayPushString( g_daKnives[ 2 ], "models/p_knife.mdl" );
								++iSize2;
							}
						case 3:
							while ( iSize2 < iSize )
							{
								ArrayPushCell( g_daKnives[ 3 ], 250.0 );
								++iSize2;
							}
						case 4:
							while ( iSize2 < iSize )
							{
								ArrayPushCell( g_daKnives[ 4 ], 1.0 );
								++iSize2;
							}
						case 5:
							while ( iSize2 < iSize )
							{
								ArrayPushCell( g_daKnives[ 5 ], 0.0 );
								++iSize2;
							}
						case 8:
							while ( iSize2 < iSize )
							{
								ArrayPushCell( g_daKnives[ 8 ], 255 );
								++iSize2;
							}
						default:
							while ( iSize2 < iSize )
							{
								ArrayPushCell( g_daKnives[ i ], 0 );
								++iSize2;
							}
					}
					
					while ( iSize2 > iSize )
						ArrayDeleteItem( g_daKnives[ i ], --iSize2 );
				}

				sBuffer[ strlen( sBuffer ) - 1 ] = 0;
				ArrayPushString( g_daKnives[ 0 ], sBuffer[ 1 ] );
				continue;
			}
			
			strtok( sBuffer, sKey, charsmax( sKey ), sValue, charsmax( sValue ), '=' );
			trim( sKey );
			trim( sValue );
			
			for ( new i; i < sizeof ( g_daKnives ); ++i )
				if ( equali( sKEYS[ i ], sKey ) )
					switch ( i )
					{
						case 1, 2: fnArrayPushModel( sValue, charsmax( sValue ), i );
						case 3, 4, 5: ArrayPushCell( g_daKnives[ i ], ( i == 4 ) ? ( str_to_float( sValue ) / 800.00 ) : ( str_to_float( sValue ) ) );
						default: ArrayPushCell( g_daKnives[ i ], str_to_num( sValue ) );
					}
		}

		fclose( pFile );
		iSize = ArraySize( g_daKnives[ 0 ] );

		for ( i = 1; i < sizeof ( g_daKnives ); ++i )
		{
			iSize2 = ArraySize( g_daKnives[ i ] );
			
			switch ( i )
			{
				case 1:
					while ( iSize2 < iSize )
					{
						ArrayPushString( g_daKnives[ 1 ], "models/v_knife.mdl" );
						++iSize2;
					}
				case 2:
					while ( iSize2 < iSize )
					{
						ArrayPushString( g_daKnives[ 2 ], "models/p_knife.mdl" );
						++iSize2;
					}
				case 3:
					while ( iSize2 < iSize )
					{
						ArrayPushCell( g_daKnives[ 3 ], 250.0 );
						++iSize2;
					}
				case 4:
					while ( iSize2 < iSize )
					{
						ArrayPushCell( g_daKnives[ 4 ], 1.0 );
						++iSize2;
					}
				case 5:
					while ( iSize2 < iSize )
					{
						ArrayPushCell( g_daKnives[ 5 ], 0.0 );
						++iSize2;
					}
				case 8:
					while ( iSize2 < iSize )
					{
						ArrayPushCell( g_daKnives[ 8 ], 255 );
						++iSize2;
					}
				default:
					while ( iSize2 < iSize )
					{
						ArrayPushCell( g_daKnives[ i ], 0 );
						++iSize2;
					}
			}
			
			while ( iSize2 > iSize )
				ArrayDeleteItem( g_daKnives[ i ], --iSize2 );
		}
	}
	else
	{
		format( sFile, charsmax( sFile ), "%L", LANG_SERVER, "MISSINGFILE", sFile );
		set_fail_state( sFile );
	}

	get_localinfo( "amxx_configsdir", sFile, charsmax( sFile ) );
	add( sFile, charsmax( sFile ), "/levels.txt" );

	pFile = fopen( sFile, "rt" );

	if ( pFile )
	{
		new sData[ 3 ][ 16 ], iNum, iFrom, iTo, iWith, iSize;

		while ( !feof( pFile ) )
		{
			fgets( pFile, sBuffer, charsmax( sBuffer ) );
			replace( sBuffer, charsmax( sBuffer ), "^n", "" );
			remove_quotes( sBuffer );

			if ( is_str_num( sBuffer ) )
				ArrayPushCell( g_daLevels, str_to_num( sBuffer ) );
			else
			{
				replace( sBuffer, charsmax( sBuffer ), "...", " " );
				replace( sBuffer, charsmax( sBuffer ), ",", " " );
				parse( sBuffer, sData[ 0 ], charsmax( sData[ ] ), sData[ 1 ], charsmax( sData[ ] ), sData[ 2 ], charsmax( sData[ ] ) );

				iFrom = str_to_num( sData[ 0 ] );
				iTo = str_to_num( sData[ 1 ] );
				iWith = str_to_num( sData[ 2 ] );
				iSize = ArraySize( g_daLevels );

				if ( iFrom > iSize )
					iFrom = iSize;

				iNum = ArrayGetCell( g_daLevels, iFrom - 1 );				

				for ( new i = iFrom; i <= iTo; ++i )
					ArrayPushCell( g_daLevels, iNum += iWith );
			}
		}
		fclose( pFile );
	}
	else
	{
		format( sFile, charsmax( sFile ), "%L", LANG_SERVER, "MISSINGFILE", sFile );
		set_fail_state( sFile );
	}
}

@naRegItem( iPluginId, iParamNum )
{
	new sItemName[ 32 ], sItemFunc[ 32 ], iCost;
	
	get_string( 1, sItemName, charsmax( sItemName ) );
	get_string( 2, sItemFunc, charsmax( sItemFunc ) );
	iCost = get_param( 3 );
	
	if ( iCost < 0 )
		iCost = 0;

	ArrayPushString( g_daItemName, sItemName );
	ArrayPushCell( g_daItemPluginId, iPluginId );
	ArrayPushCell( g_daItemCost, iCost );
	ArrayPushCell( g_daItemFuncId, get_func_id( sItemFunc, iPluginId ) );
	
	return ( ArraySize( g_daItemCost ) - 1 );
}

@naGetKnifeInfo( iPluginId, iParamNum )
	if ( iParamNum == 3 )
	{
		new sKnifeInfo[ 32 ];
		ArrayGetString( g_daKnives[ get_param( 1 ) ], get_param( 2 ), sKnifeInfo, charsmax( sKnifeInfo ) );
		set_string( 3, sKnifeInfo, charsmax( sKnifeInfo ) );
		return 1;
	}
	else
		return ArrayGetCell( g_daKnives[ get_param( 1 ) ], get_param( 2 ) );

@naGetPlayerInfo( iPluginId, iParamNum )
	return g_iPlayerInfos[ get_param( 1 ) ][ get_param( 2 ) ];

@naGetMaxLvl( iPluginId, iParamNum )
	return ( ArraySize( g_daLevels ) - 1 );

@fwTakeDamagePre( iVictim, iInflictor, iAttacker, Float:fDamagePre, iDmgBits )
	if ( IS_PLAYER( iAttacker ) && iAttacker != iVictim )
		if ( get_user_weapon( iAttacker ) == CSW_KNIFE )
		{
			SetHamParamFloat( 4, fDamagePre + Float:ArrayGetCell( g_daKnives[ 5 ], g_iPlayerInfos[ iAttacker ][ iPlayerSelected ] ) );
			new iKB = ArrayGetCell( g_daKnives[ 6 ], g_iPlayerInfos[ iAttacker ][ iPlayerSelected ] );
			
			if ( iKB > 0 )
			{
				new Float:fOldVelo[ 3 ], Float:fVec[ 3 ];
				entity_get_vector( iVictim, EV_VEC_velocity, fOldVelo );
				if ( fnCreateKnockback( iVictim, iAttacker, fVec, iKB ) )
				{
					fVec[0] += fOldVelo[0];
					fVec[1] += fOldVelo[1];
					entity_set_vector( iVictim, EV_VEC_velocity, fVec );
				}
			}
		}

@fwWeaponKnifePost( iEnt )
	if ( pev_valid( iEnt ) == 2 )
	{
		new iOwner = get_pdata_cbase( iEnt, 41, 4 );
		if ( pev_valid( iOwner ) )
		{
			new sModels[ 32 ];
			ArrayGetString( g_daKnives[ 1 ], g_iPlayerInfos[ iOwner ][ iPlayerSelected ], sModels, charsmax( sModels ) );
			entity_set_string( iOwner, EV_SZ_viewmodel, sModels );
			ArrayGetString( g_daKnives[ 2 ], g_iPlayerInfos[ iOwner ][ iPlayerSelected ], sModels, charsmax( sModels ) );
			entity_set_string( iOwner, EV_SZ_weaponmodel, sModels );
		}
	}

@fwPlayerSpawnPost( iPlayerId )
	if ( is_user_alive( iPlayerId ) )
		switch ( g_iMap )
		{
			case 1: set_task( 2.5, "@fnSpawnSettings", iPlayerId );
			case 35: set_task( 2.0, "@fnSpawnSettings", iPlayerId );
			default: @fnSpawnSettings( iPlayerId );
		}

@fwResetMaxSpeedPost( iPlayerId )
	if ( is_user_alive( iPlayerId ) && get_user_maxspeed( iPlayerId ) > 1.0 )
		set_user_maxspeed( iPlayerId, Float:ArrayGetCell( g_daKnives[ 3 ], g_iPlayerInfos[ iPlayerId ][ iPlayerSelected ] ) );

//Bugfix
@fnSpawnSettings( iPlayerId )
{
	set_user_health( iPlayerId, g_iMap + ArrayGetCell( g_daKnives[ 7 ], g_iPlayerInfos[ iPlayerId ][ iPlayerSelected ] ) );

	set_user_rendering( iPlayerId, kRenderFxGlowShell, 0, 0, 0, kRenderTransAlpha, ArrayGetCell( g_daKnives[ 8 ], g_iPlayerInfos[ iPlayerId ][ iPlayerSelected ] ) );

	set_user_gravity( iPlayerId, Float:ArrayGetCell( g_daKnives[ 4 ], g_iPlayerInfos[ iPlayerId ][ iPlayerSelected ] ) );
}

// Bugfix
@msgHealth( iMsgId, iMsgDest, iMsgEnt )
{
	new iHp = get_msg_arg_int( 1 );
	if ( iHp > 256 )
	{
		if ( iHp % 256 == 0 )
			( iHp > 0 ) ? set_user_health( iMsgEnt, get_user_health( iMsgEnt ) + 1 ) : user_kill( iMsgEnt, 1 );
		
		set_msg_arg_int( 1, get_msg_argtype( 1 ), 255 );
	}
}

@evDeath( )
{
	new iKiller = read_data( 1 );

	if ( IS_PLAYER( iKiller ) && is_user_connected( iKiller ) )
	{
		new iVictim = read_data( 2 );
		new iHs = read_data( 3 );
		new iXp, iPoint;
	
		iXp = iHs ? get_pcvar_num( g_pCvars[ 1 ] ) : get_pcvar_num( g_pCvars[ 3 ] );
		iPoint = iHs ? get_pcvar_num( g_pCvars[ 2 ] ) : get_pcvar_num( g_pCvars[ 4 ] );
		
		g_iPlayerInfos[ iKiller ][ iPlayerXp ] += iXp;
		g_iPlayerInfos[ iKiller ][ iPlayerPoints ] += iPoint;
		
		switch ( get_pcvar_num( g_pCvars[ 0 ] ) )
		{
			case 1:	client_print_color( iKiller, iKiller, "%L", LANG_SERVER, "KILLSGMKILLER", g_sPlayerName[ iVictim ], iXp, iPoint );
			case 2:
			{
				client_print_color( iKiller, iKiller, "%L", LANG_SERVER, "KILLSGMKILLER", g_sPlayerName[ iVictim ], iXp, iPoint );
				client_print_color( iVictim, iVictim, "%L", LANG_SERVER, "KILLMSGVICTIM", g_sPlayerName[ iKiller ] );
			}
		}
	}
	fnCheckLevel( iKiller );
}

@fnShowMenu( iPlayerId ) 
	fnMainMenu( iPlayerId, 0 );

fnMainMenu( iPlayerId, iMenu )
{
	new sMenu[ 78 ], sInfo[ 16 ], iMenuId;
	
	switch ( iMenu )
	{
		case 0:
		{
			formatex( sMenu, charsmax( sMenu ), "%L", LANG_SERVER, "MENU0", g_iPlayerInfos[ iPlayerId ][ iPlayerLvl ], g_iPlayerInfos[ iPlayerId ][ iPlayerXp ], ArrayGetCell( g_daLevels, g_iPlayerInfos[ iPlayerId ][ iPlayerLvl ] ), g_iPlayerInfos[ iPlayerId ][ iPlayerPoints ]  );
			iMenuId = menu_create( sMenu, "@fnMenuHandler" );
			
			formatex( sMenu, charsmax( sMenu ), "%L", LANG_SERVER, "KNIFEMENU" );
			menu_additem( iMenuId, sMenu, "1 0" );
			formatex( sMenu, charsmax( sMenu ), "%L", LANG_SERVER, "GIFTINGMENU" );
			menu_additem( iMenuId, sMenu, "2 0" );
			if ( ArraySize( g_daItemCost ) )
			{
				formatex( sMenu, charsmax( sMenu ), "%L", LANG_SERVER, "SHOPMENU" );
				menu_additem( iMenuId, sMenu, "3 0" );
			}
			formatex( sMenu, charsmax( sMenu ), "%L", LANG_SERVER, "PLAYERSMENU" );
			menu_additem( iMenuId, sMenu, "4 0" );
			formatex( sMenu, charsmax( sMenu ), "%L", LANG_SERVER, "ADDINGMENU" );
			menu_additem( iMenuId, sMenu, "5 0", g_iADD_FLAG );
		}
		case 1:
		{
			formatex( sMenu, charsmax( sMenu ), "%L", LANG_SERVER, "MENU1", g_iPlayerInfos[ iPlayerId ][ iPlayerLvl ], g_iPlayerInfos[ iPlayerId ][ iPlayerXp ], ArrayGetCell( g_daLevels, g_iPlayerInfos[ iPlayerId ][ iPlayerLvl ] ) );
			iMenuId = menu_create( sMenu, "@fnMenuHandler" );

			new iSize = ArraySize( g_daKnives[ 0 ] );
			for ( new i; i < iSize; ++i )
			{
				ArrayGetString( g_daKnives[ 0 ], i, sMenu, charsmax( sMenu ) );
				format( sMenu, charsmax( sMenu ), "%L", LANG_SERVER, "KNIVES", sMenu, ArrayGetCell( g_daKnives[ 9 ], i ) );
				formatex( sInfo, charsmax( sInfo ), "%i 1", i );
				menu_additem( iMenuId, sMenu, sInfo );
			}
		}
		case 2:
		{
			formatex( sMenu, charsmax( sMenu ), "%L", LANG_SERVER, "MENU2", g_iPlayerInfos[ iPlayerId ][ iPlayerPoints ]  );
			iMenuId = menu_create( sMenu, "@fnMenuHandler" );

			new iPlayers[ 32 ], iPlayerNum;
			get_players( iPlayers, iPlayerNum, "ch" );
			
			for ( new i; i < iPlayerNum; ++i )
				if ( iPlayers[ i ] != iPlayerId )
				{
					formatex( sInfo, charsmax( sInfo ), "%i 2", iPlayers[ i ] );
					menu_additem( iMenuId, g_sPlayerName[ iPlayers[ i ] ], sInfo );
				}
		}
		case 3:
		{
			formatex( sMenu, charsmax( sMenu ), "%L", LANG_SERVER, "MENU3", g_iPlayerInfos[ iPlayerId ][ iPlayerPoints ]  );
			iMenuId = menu_create( sMenu, "@fnMenuHandler" );

			new iSize = ArraySize( g_daItemCost );
			for ( new i; i < iSize; ++i )
			{
				ArrayGetString( g_daItemName, i, sMenu, charsmax( sMenu ) );
				format( sMenu, charsmax( sMenu ), "%L", LANG_SERVER, "ITEMINSHOP", sMenu, ArrayGetCell( g_daItemCost, i ) );
				formatex( sInfo, charsmax( sInfo ), "%i 3", i );
				menu_additem( iMenuId, sMenu, sInfo );
			}
		}
		case 4:
		{
			formatex( sMenu, charsmax( sMenu ), "%L", LANG_SERVER, "MENU4", g_iPlayerInfos[ iPlayerId ][ iPlayerLvl ], g_iPlayerInfos[ iPlayerId ][ iPlayerXp ], ArrayGetCell( g_daLevels, g_iPlayerInfos[ iPlayerId ][ iPlayerLvl ] ), g_iPlayerInfos[ iPlayerId ][ iPlayerPoints ]  );
			iMenuId = menu_create( sMenu, "@fnMenuHandler" );

			new iPlayers[ 32 ], iPlayerNum, iTempId;
			get_players( iPlayers, iPlayerNum, "ch" );
			
			for ( new i; i < iPlayerNum; ++i )
				if ( iPlayers[ i ] != iPlayerId )
				{
					iTempId = iPlayers[ i ];
					formatex( sMenu, charsmax( sMenu ), "%L", LANG_SERVER, "PLAYERINMENU", g_sPlayerName[ iTempId ], g_iPlayerInfos[ iTempId ][ iPlayerLvl ], g_iPlayerInfos[ iTempId ][ iPlayerXp ], ArrayGetCell( g_daLevels, g_iPlayerInfos[ iTempId ][ iPlayerLvl ] ), g_iPlayerInfos[ iTempId ][ iPlayerPoints ] );
					formatex( sInfo, charsmax( sInfo ), "%i 4", iTempId );
					menu_additem( iMenuId, sMenu, sInfo );
				}
		}
		case 5:
		{
			formatex( sMenu, charsmax( sMenu ), "%L", LANG_SERVER, "MENU5" );
			iMenuId = menu_create( sMenu, "@fnMenuHandler" );

			new iPlayers[ 32 ], iPlayerNum;
			get_players( iPlayers, iPlayerNum, "ch" );
			
			for ( new i; i < iPlayerNum; ++i )
			{
				formatex( sInfo, charsmax( sInfo ), "%i 5", iPlayers[ i ] );
				menu_additem( iMenuId, g_sPlayerName[ iPlayers[ i ] ], sInfo );
			}
		}
	}
	menu_setprop( iMenuId, MPROP_EXIT, MEXIT_ALL );
	menu_display( iPlayerId, iMenuId, 0 );
}

@fnMenuHandler( iPlayerId, iMenuId, iItem )
{
	if ( iItem != MENU_EXIT )
	{
		new sMenuName[ 78 ], sInfo[ 32 ], sDatas[ 2 ][ 16 ], iKey, iMenuNum;
		menu_item_getinfo( iMenuId, iItem, iKey, sInfo, charsmax( sInfo ), sMenuName, charsmax( sMenuName ), iMenuNum );
		parse( sInfo, sDatas[ 0 ], charsmax( sDatas[ ] ), sDatas[ 1 ], charsmax( sDatas[ ] ) );
		iKey = str_to_num( sDatas[ 0 ] );
		iMenuNum = str_to_num( sDatas[ 1 ] );

		switch ( iMenuNum )
		{
			case 0:
			{
				fnMainMenu( iPlayerId, iKey );
			}
			case 1:
			{
				if ( g_iPlayerInfos[ iPlayerId ][ iPlayerLvl ] >= ArrayGetCell( g_daKnives[ 9 ], iKey ) )
				{
					new iRet;
					g_iPlayerInfos[ iPlayerId ][ iPlayerSelected ] = iKey;
					ExecuteForward( g_iForwards[ 2 ], iRet, iPlayerId, g_iPlayerInfos[ iPlayerId ][ iPlayerSelected ] );
					
					if ( get_user_weapon( iPlayerId ) == CSW_KNIFE )
					{
						ArrayGetString( g_daKnives[ 1 ], g_iPlayerInfos[ iPlayerId ][ iPlayerSelected ], sMenuName, charsmax( sMenuName ) );
						entity_set_string( iPlayerId, EV_SZ_viewmodel, sMenuName );

						ArrayGetString( g_daKnives[ 2 ], g_iPlayerInfos[ iPlayerId ][ iPlayerSelected ], sMenuName, charsmax( sMenuName ) );
						entity_set_string( iPlayerId, EV_SZ_weaponmodel, sMenuName );
					}

					set_user_rendering( iPlayerId, kRenderFxGlowShell, 0, 0, 0, kRenderTransAlpha, ArrayGetCell( g_daKnives[ 8 ], g_iPlayerInfos[ iPlayerId ][ iPlayerSelected ] ) );

					set_user_gravity( iPlayerId, Float:ArrayGetCell( g_daKnives[ 4 ], g_iPlayerInfos[ iPlayerId ][ iPlayerSelected ] ) );
					
					if ( get_user_maxspeed( iPlayerId ) > 1.0 )
						set_user_maxspeed( iPlayerId, Float:ArrayGetCell( g_daKnives[ 3 ], g_iPlayerInfos[ iPlayerId ][ iPlayerSelected ] ) );
				}
				else
					client_print_color( iPlayerId, iPlayerId, "%L", LANG_SERVER, "NOTENOUGHLVL", g_sPREFIX );
			}
			case 2:
			{
				if ( is_user_connected( iKey ) )
				{
					g_iTarget[ iPlayerId ] = iKey;
					client_cmd( iPlayerId, "messagemode GIFT" );
				}
				else
				{
					client_print_color( iPlayerId, iPlayerId, "%L", LANG_SERVER, "TARGETDISCONNECTED", g_sPREFIX );
					fnMainMenu( iPlayerId, 2 );
				}
			}
			case 3:
			{
				if ( g_iPlayerInfos[ iPlayerId ][ iPlayerPoints ] >= ArrayGetCell( g_daItemCost, iKey ) )
				{
					new sItemName[ 32 ];
					g_iPlayerInfos[ iPlayerId ][ iPlayerPoints ] -= ArrayGetCell( g_daItemCost, iKey );
					ArrayGetString( g_daItemName, iKey, sItemName, charsmax( sItemName ) );

					callfunc_begin_i( ArrayGetCell( g_daItemFuncId, iKey ), ArrayGetCell( g_daItemPluginId, iKey ) );
					callfunc_push_int( iPlayerId );
					callfunc_push_int( iKey );
					callfunc_end( );

					client_print_color( iPlayerId, iPlayerId, "%L", LANG_SERVER, "SUCCPURCHASE", g_sPREFIX, sItemName );
				}
				else
					client_print_color( iPlayerId, iPlayerId, "%L", LANG_SERVER, "UNSUCCPURCHASE", g_sPREFIX );
			}
			case 4:
			{
				if ( is_user_connected( iKey ) )
					client_print_color( iPlayerId, iPlayerId, "%L", LANG_SERVER, "PLAYERINMENU", g_sPlayerName[ iKey ], g_iPlayerInfos[ iKey ][ iPlayerLvl ], g_iPlayerInfos[ iKey ][ iPlayerXp ], ArrayGetCell( g_daLevels, g_iPlayerInfos[ iKey ][ iPlayerLvl ] ) );
				else
				{
					client_print_color( iPlayerId, iPlayerId, "%L", LANG_SERVER, "TARGETDISCONNECTED", g_sPREFIX );
					fnMainMenu( iPlayerId, 4 );
				}
			}
			case 5:
			{
				if ( is_user_connected( iKey ) )
				{
					g_iTarget[ iPlayerId ] = iKey;
					client_cmd( iPlayerId, "messagemode ADD" );
				}
				else
				{
					client_print_color( iPlayerId, iPlayerId, "%L", LANG_SERVER, "TARGETDISCONNECTED", g_sPREFIX );
					fnMainMenu( iPlayerId, 5 );
				}
			}
		}
	}
	menu_destroy( iMenuId );
	return PLUGIN_HANDLED;
}

@fnGiftHandler( iPlayerId )
{
	new sData[ 191 ], iNum;
	read_args( sData, charsmax( sData ) );
	remove_quotes( sData );
	
	if ( is_str_num( sData ) )
	{
		iNum = str_to_num( sData );
		
		if ( g_iPlayerInfos[ iPlayerId ][ iPlayerPoints ] >= iNum )
		{
			g_iPlayerInfos[ g_iTarget[ iPlayerId ] ][ iPlayerPoints ] += iNum;
			g_iPlayerInfos[ iPlayerId ][ iPlayerPoints ] -= iNum;
			client_print_color( iPlayerId, iPlayerId, "%L", LANG_SERVER, "SUCCGIFTING", g_sPREFIX, g_sPlayerName[ g_iTarget [ iPlayerId ] ], iNum );
			client_print_color( g_iTarget[ iPlayerId ], g_iTarget[ iPlayerId ], "%L", LANG_SERVER, "GETPOINTS", g_sPREFIX, iNum, g_sPlayerName[ iPlayerId ] );
		}
		else
			client_print_color( iPlayerId, iPlayerId, "%L", LANG_SERVER, "NOTENOUGHPOINT", g_sPREFIX );
	}
	else
	{
		client_print_color( iPlayerId, iPlayerId, "%L", LANG_SERVER, "INVALIDVALUE", g_sPREFIX );
		client_cmd( iPlayerId, "messagemode GIFT" );
	}
}

@fnAddHandler( iPlayerId )
{
	new sData[ 191 ], iNum;
	read_args( sData, charsmax( sData ) );
	remove_quotes( sData );
	
	if ( is_str_num( sData ) )
	{
		iNum = str_to_num( sData );
		
		g_iPlayerInfos[ g_iTarget[ iPlayerId ] ][ iPlayerPoints ] += iNum;
		client_print_color( 0, print_team_default, "%L", LANG_SERVER, "ADDTEXT", g_sPREFIX, g_sPlayerName[ iPlayerId ], g_sPlayerName[ g_iTarget[ iPlayerId ] ], iNum );
	}
	else
	{
		client_print_color( iPlayerId, iPlayerId, "%L", LANG_SERVER, "INVALIDVALUE", g_sPREFIX );
		client_cmd( iPlayerId, "messagemode ADD" );
	}
}

public client_infochanged( iPlayerId )
{
	new sNewName[ 32 ];
	get_user_info( iPlayerId, "name", sNewName, charsmax( sNewName ) );
	
	if ( !equal( g_sPlayerName[ iPlayerId ], sNewName ) )
	{
		g_sPlayerName[ iPlayerId ][ 0 ] = EOS;
		copy( g_sPlayerName[ iPlayerId ], charsmax( g_sPlayerName[ ] ), sNewName );
	}
}

public client_authorized( iPlayerId )
	if ( !is_user_bot( iPlayerId ) )
	{
		new sSteamId[ 32 ];
		get_user_authid( iPlayerId, sSteamId, charsmax( sSteamId ) );
		get_user_name( iPlayerId, g_sPlayerName[ iPlayerId ], charsmax( g_sPlayerName[ ] ) );
		fnLoadPlayerDatas( iPlayerId, sSteamId );
	}

public client_disconnect( iPlayerId )
	if ( !is_user_bot( iPlayerId ) )
	{
		new sSteamId[ 32 ];
		get_user_authid( iPlayerId, sSteamId, charsmax( sSteamId ) );
		#if defined SQL
		fnSavePlayerDatas( iPlayerId, sSteamId, 0 );
		#else
		fnSavePlayerDatas( iPlayerId, sSteamId );
		#endif
	}

#if defined SQL

fnLoadPlayerDatas( iPlayerId, const sSteamId[ ] )
{
	new sText[ 128 ], iArray[ 2 ];
	iArray[ 0 ] = iPlayerId;
	iArray[ 1 ] = get_user_userid( iPlayerId );

	formatex( sText, charsmax( sText ), "SELECT * FROM `KnifeSystem` WHERE SteamId = ^"%s^"", sSteamId );
	SQL_ThreadQuery( g_iSqlTuple, "@fnThreadHandler", sTxt, iArray, sizeof( iArray ) );
}

fnSavePlayerDatas( iPlayerId, const sSteamId[ ], iMode )
{
	new sText[ 512 ];

	if ( iMode )
		formatex( sText, charsmax( sText ), "INSERT INTO `KnifeSystem` ( `SteamId`,`Level`,`Xp`,`Points`,`Selected` ) VALUES ( ^"%s^", ^"0^", ^"0^", ^"0^", ^"0^" )", sSteamId );
	else
		formatex( sText, charsmax( sText ), "UPDATE `KnifeSystem` SET Level = ^"%i^" Xp = ^"%i^" Points = ^"%i^" Selected = ^"%i^" WHERE SteamId = ^"%s^"", g_iPlayerInfos[ iPlayerId ][ iPlayerLvl ], g_iPlayerInfos[ iPlayerId ][ iPlayerXp ], g_iPlayerInfos[ iPlayerId ][ iPlayerPoints ], g_iPlayerInfos[ iPlayerId ][ iPlayerSelected ], sSteamId );
}

@fnThreadHandler( iFailState, Handle:iQuery, sErrorMsg[ ], iErrorCode, Array[ ], iArraySize, Float:fQueueTime )
{
	new sText[ 128 ];
	if ( iFailState == TQUERY_CONNECT_FAILED )
	{
		formatex( sText, charsmax( sText ), "%L", LANG_SERVER, "TQUERY_CONNECT_FAILED" );
		set_fail_state( sText );
		return;
	}
	else if ( iFailState == TQUERY_QUERY_FAILED )
	{
		formatex( sText, charsmax( sText ), "%L", LANG_SERVER, "TQUERY_QUERY_FAILED" );
		set_fail_state( sText );
		return;
	}

	if ( iErrorCode )
	{
		log_amx( "%i - %s", iErrorCode, sErrorMsg );
		return;
	}

	new iPlayerId = Array[ 0 ];

	if ( iPlayerId && Array[ 1 ] == get_user_userid( iPlayerId ) )
		if ( SQL_NumResults( iQuery ) > 0 )
		{
			g_iPlayerInfos[ iPlayerId ][ iPlayerSelected ] = SQL_ReadResult( iQuery, SQL_FieldNameToNum( iQuery, "Selected" ) );
			g_iPlayerInfos[ iPlayerId ][ iPlayerPoints ] = SQL_ReadResult( iQuery, SQL_FieldNameToNum( iQuery, "Points" ) );
			g_iPlayerInfos[ iPlayerId ][ iPlayerLvl ] = SQL_ReadResult( iQuery, SQL_FieldNameToNum( iQuery, "Level" ) );
			g_iPlayerInfos[ iPlayerId ][ iPlayerXp ] = SQL_ReadResult( iQuery, SQL_FieldNameToNum( iQuery, "Xp" ) );
		}
		else
			fnSavePlayerDatas( iPlayerId, 1 );

	return;
}

#else

fnLoadPlayerDatas( iPlayerId, const sSteamId[ ] )
{
	new sData[ 51 ];

	if ( nvault_get( g_iNvaultId, sSteamId, sData, charsmax( sData ) ) )
	{
		new sLevel[ 11 ], sXp[ 11 ], sPoints[ 11 ], sSelected[ 11 ];
		parse( sData, sLevel, charsmax( sLevel ), sXp, charsmax( sXp ), sPoints, charsmax( sPoints ), sSelected, charsmax( sSelected ) );
		g_iPlayerInfos[ iPlayerId ][ iPlayerLvl ] = str_to_num( sLevel );
		g_iPlayerInfos[ iPlayerId ][ iPlayerXp ] = str_to_num( sXp );
		g_iPlayerInfos[ iPlayerId ][ iPlayerPoints ] = str_to_num( sPoints );
		g_iPlayerInfos[ iPlayerId ][ iPlayerSelected ] = str_to_num( sSelected );
	}
	else
		arrayset( g_iPlayerInfos[ iPlayerId ], 0, sizeof( g_iPlayerInfos[ ] ) );
}

fnSavePlayerDatas( iPlayerId, const sSteamId[ ] )
{
	new sData[ 51 ];

	formatex( sData, charsmax( sData ), " %i %i %i %i ", g_iPlayerInfos[ iPlayerId ][ iPlayerLvl ], g_iPlayerInfos[ iPlayerId ][ iPlayerXp ], g_iPlayerInfos[ iPlayerId ][ iPlayerPoints ], g_iPlayerInfos[ iPlayerId ][ iPlayerSelected ] );
	nvault_set( g_iNvaultId, sSteamId, sData );
}

#endif

fnArrayPushModel( sMdl[ ], iMdl, iArrayId )
{
	if ( !equal( sMdl, "models/", 7 ) )
		format( sMdl, iMdl, "models/%s", sMdl );
	
	if ( !equal( sMdl[ strlen( sMdl ) - 4 ], ".mdl", 4 ) )
		add( sMdl, iMdl, ".mdl" );

	precache_model( sMdl );
	ArrayPushString( g_daKnives[ iArrayId ], sMdl );
}

fnCheckLevel( iPlayerId )
{
	new iMax = ArraySize( g_daLevels ) - 1;
	if ( g_iPlayerInfos[ iPlayerId ][ iPlayerLvl ] < iMax )
	{
		new iRet;
		while ( g_iPlayerInfos[ iPlayerId ][ iPlayerXp ] >= ArrayGetCell( g_daLevels, g_iPlayerInfos[ iPlayerId ][ iPlayerLvl ] ) )
		{
			++g_iPlayerInfos[ iPlayerId ][ iPlayerLvl ];
			ExecuteForward( g_iForwards[ 0 ], iRet, iPlayerId, g_iPlayerInfos[ iPlayerId ][ iPlayerLvl ] );
			
			if ( g_iPlayerInfos[ iPlayerId ][ iPlayerLvl ] == iMax )
			{
				ExecuteForward( g_iForwards[ 1 ], iRet, iPlayerId );
				break;
			}
		}
	}
}

fnCreateKnockback( iVictim, iAttacker, Float:fVec[ 3 ], iKB )
{
	if ( !is_user_alive( iVictim ) || !is_user_alive( iAttacker ) )
		return 0;
	
	new Float:fVictimO[ 3 ], Float:fAttackerO[ 3 ], Float:fOrigin[ 3 ];
	entity_get_vector( iVictim, EV_VEC_origin, fVictimO );
	entity_get_vector( iAttacker, EV_VEC_origin, fAttackerO );
	
	fOrigin[ 0 ] = fVictimO[ 0 ] - fAttackerO[ 0 ];
	fOrigin[ 1 ] = fVictimO[ 1 ] - fAttackerO[ 0 ];
	
	new Float:iLargestNum = 0.0;

	if ( floatabs( fOrigin[0] ) > iLargestNum ) iLargestNum = floatabs( fOrigin[0] );
	if ( floatabs( fOrigin[1] ) > iLargestNum ) iLargestNum = floatabs( fOrigin[1] );
	
	fOrigin[0] /= iLargestNum;
	fOrigin[1] /= iLargestNum;

	fVec[0] = ( fOrigin[0] * ( iKB * 3000) ) / get_entity_distance( iVictim, iAttacker );
	fVec[1] = ( fOrigin[1] * ( iKB * 3000) ) / get_entity_distance( iVictim, iAttacker );
	if( fVec[0] <= 20.0 || fVec[1] <= 20.0 )
		fVec[2] = random_float( 200.0, 275.0 );
	
	return 1;
}

public plugin_end( )
{
	for ( new i; i < sizeof( g_daKnives ); ++i )
		ArrayDestroy( g_daKnives[ i ] );

	ArrayDestroy( g_daLevels );
	ArrayDestroy( g_daItemCost );
	ArrayDestroy( g_daItemFuncId );
	ArrayDestroy( g_daItemName );
	ArrayDestroy( g_daItemPluginId );

#if defined SQL
	SQL_FreeHandle( g_iSqlTuple );
#else
	nvault_close( g_iNvaultId );
#endif
}

/*
new const g_sWeaponEntNames[ ][ ] =
{
	"x", "weapon_p228", "x", "weapon_scout", "weapon_hegrenade", "weapon_xm1014", 
	"weapon_c4", "weapon_mac10", "weapon_aug", "weapon_smokegrenade", 
	"weapon_elite", "weapon_fiveseven", "weapon_ump45", "weapon_sg550", 
	"weapon_galil", "weapon_famas", "weapon_usp", "weapon_glock18", 
	"weapon_awp", "weapon_mp5navy", "weapon_m249", "weapon_m3", 
	"weapon_m4a1", "weapon_tmp", "weapon_g3sg1", "weapon_flashbang", 
	"weapon_deagle", "weapon_sg552", "weapon_ak47", "weapon_knife", "weapon_p90"
}
*/
