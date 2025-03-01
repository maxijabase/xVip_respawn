#include <sourcemod>
#include <tf2_stocks>
#include <clientprefs>
#include <sdktools>
#include <xVip>

#undef REQUIRE_PLUGIN
#include <updater>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "2.4"
#define UPDATE_URL "https://raw.githubusercontent.com/maxijabase/xVip_respawn/main/updatefile.txt"

public Plugin myinfo = 
{
	name = "xVip - Respawn", 
	author = "Mathx, modified by ampere", 
	description = "Customizable respawn plugin for VIPs. Originally by Mathx from vip Brazil.", 
	version = PLUGIN_VERSION, 
	url = "http://steamcommunity.com/profiles/76561198039524991"
}

enum TFGameType {
	TFGame_Unknown, 
	TFGame_CaptureTheFlag, 
	TFGame_CapturePoint, 
	TFGame_Payload, 
	TFGame_Arena, 
	TFGame_MannVsMachine, 
	TFGame_PassTime, 
	TFGame_PlayerDestruction, 
}

enum RespawnMode {
	RespawnMode_PressingE, 
	RespawnMode_AlwaysInstant
}

RespawnMode g_iRespawnMode[MAXPLAYERS + 1] = { RespawnMode_PressingE, ... };

float g_flLastRespawnTime[MAXPLAYERS + 1] = { 0.0, ... };

Cookie g_hRespawnModeCookie;
Handle g_hHUDSynchronizer;

bool g_bZatoichi[MAXPLAYERS + 1];

ConVar g_cvEnabled;
ConVar g_cvDebug;

public void OnPluginStart()
{
	CreateConVar("vip_respawn_version", PLUGIN_VERSION, .flags = FCVAR_NOTIFY | FCVAR_DONTRECORD);
	
	g_cvEnabled = CreateConVar("vip_respawn_enabled", "1", "Enable/disable the plugin", _, true, 0.0, true, 1.0);
	g_cvDebug = CreateConVar("sm_viprespawn_debug", "0", "Enable/disable debug messages", _, true, 0.0, true, 1.0);
	
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Post);
	HookEvent("player_death", OnPlayerDeath_Pre, EventHookMode_Pre);
	
	g_hRespawnModeCookie = RegClientCookie("respawn_mode", "Respawn mode", CookieAccess_Private);
	SetCookieMenuItem(CookieMenu_Top, 0, "Respawn Mode");
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (AreClientCookiesCached(i))
		{
			OnClientCookiesCached(i);
		}
	}
	
	g_hHUDSynchronizer = CreateHudSynchronizer();
	
	AddCommandListener(OnVoiceMenu, "voicemenu");
	
	// Add listeners for class and team changes
	AddCommandListener(OnClassChange, "joinclass");
	AddCommandListener(OnClassChange, "jointeam");
	
	AutoExecConfig(true);
	LoadTranslations("xVip_respawn.phrases");
	
	RegConsoleCmd("sm_respawnmode", CMD_RespawnMode);
}

public void Updater_OnLoaded()
{
	Updater_AddPlugin(UPDATE_URL);
}

public Action CMD_RespawnMode(int client, int args) {
	SendCookieMenu(client);
	return Plugin_Handled;
}

public Action OnVoiceMenu(int client, const char[] command, int argc)
{
	if (!g_cvEnabled.BoolValue || argc < 2)
	{
		return Plugin_Continue;
	}
	
	if (GetCmdArgInt(1) == 0 && GetCmdArgInt(2) == 0)
	{
		OnMedicCall(client);
	}
	
	return Plugin_Continue;
}

public Action OnClassChange(int client, const char[] command, int argc)
{
	if (!CanClientRespawn(client, "class change"))
	{
		return Plugin_Continue;
	}
	
	// Allow the class/team change to go through first, then respawn the player
	CreateTimer(0.1, Timer_RespawnPlayer, GetClientUserId(client));
	g_flLastRespawnTime[client] = GetGameTime();
	
	return Plugin_Continue;
}

// Helper function to check if a client can respawn
bool CanClientRespawn(int client, const char[] action)
{
	if (!g_cvEnabled.BoolValue)
	{
		DebugPrint("[Check] Plugin is disabled");
		return false;
	}
	
	if (!xVip_IsVip(client))
	{
		DebugPrint("[Check] Client %d is not VIP", client);
		return false;
	}
	
	if (IsPlayerAlive(client))
	{
		DebugPrint("[Check] Client %d is already alive", client);
		return false;
	}
	
	if (!IsRespawnAllowed())
	{
		DebugPrint("[Check] Respawn is not allowed in current gamemode/state");
		return false;
	}
	
	float secondsSinceLastRespawn = GetGameTime() - g_flLastRespawnTime[client];
	if (secondsSinceLastRespawn < 3.0)
	{
		DebugPrint("[Check] Client %d respawn cooldown: %.1f seconds remaining", client, 3.0 - secondsSinceLastRespawn);
		return false;
	}
	
	DebugPrint("[Check] Client %d can respawn via %s", client, action);
	return true;
}

void OnMedicCall(int client)
{
	// Extra check specific to E-press respawn
	if (g_iRespawnMode[client] != RespawnMode_PressingE)
	{
		DebugPrint("[Check] Client %d is not in pressing E mode", client);
		return;
	}
	
	if (!CanClientRespawn(client, "medic call"))
	{
		return;
	}
	
	TF2_RespawnPlayer(client);
	g_flLastRespawnTime[client] = GetGameTime();
}

public void CookieMenu_Top(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
	if (action != CookieMenuAction_DisplayOption)
	{
		SendCookieMenu(client);
	}
}

void SendCookieMenu(int client)
{
	Menu menu = new Menu(CookieHandler);
	menu.SetTitle("%t", "Menu Title");
	
	char option1[32];
	Format(option1, sizeof(option1), "%t", "PressingE");
	menu.AddItem("pressinge", option1);
	
	char option2[32];
	Format(option2, sizeof(option2), "%t", "AlwaysInstant");
	menu.AddItem("alwaysinstant", option2);
	
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int CookieHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
			
			if (StrEqual(info, "pressinge"))
			{
				SetClientCookie(param1, g_hRespawnModeCookie, "pressinge");
				g_iRespawnMode[param1] = RespawnMode_PressingE;
			}
			else if (StrEqual(info, "alwaysinstant"))
			{
				SetClientCookie(param1, g_hRespawnModeCookie, "alwaysinstant");
				g_iRespawnMode[param1] = RespawnMode_AlwaysInstant;
			}
			
			xVip_Reply(param1, "[SM] %t", "Options Saved");
		}
		
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				ShowCookieMenu(param1);
			}
		}
	}
	
	return 0;
}

public void OnClientCookiesCached(int client)
{
	g_iRespawnMode[client] = RespawnMode_PressingE;
	
	char value[32];
	GetClientCookie(client, g_hRespawnModeCookie, value, sizeof(value));
	
	if (value[0] == '\0') {
		return;
	}
	
	if (StrEqual(value, "alwaysinstant")) {
		g_iRespawnMode[client] = RespawnMode_AlwaysInstant;
	}
}

public Action OnPlayerDeath_Pre(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);
	
	g_bZatoichi[client] = false;
	
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (weapon != INVALID_ENT_REFERENCE)
	{
		int index = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
		if (index == 357)
		{
			g_bZatoichi[client] = true;
		}
	}
	
	return Plugin_Continue;
}

public Action OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!g_cvEnabled.BoolValue || !xVip_IsVip(client) || client <= 0)
	{
		return Plugin_Continue;
	}
	
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	
	if ((event.GetInt("death_flags") & TF_DEATHFLAG_DEADRINGER) == TF_DEATHFLAG_DEADRINGER || !IsRespawnAllowed())
	{
		return Plugin_Continue;
	}
	
	RespawnMode respawnMode = g_iRespawnMode[client];
	
	if (respawnMode == RespawnMode_AlwaysInstant)
	{
		bool isTriggerHurt = event.GetInt("customkill") == TF_CUSTOM_TRIGGER_HURT;
		ApplyInstantRespawn(client, attacker, isTriggerHurt);
	}
	else if (respawnMode == RespawnMode_PressingE)
	{
		DisplayRespawnHUDMessages(client);
	}
	
	return Plugin_Continue;
}

void ApplyInstantRespawn(int client, int attacker, bool isTriggerHurt)
{
	if (!CheckCommandAccess(client, "", ADMFLAG_RESERVATION)) {
		return;
	}
	
	float time = 0.0;
	
	if (!g_bZatoichi[client] && (client != attacker) && (attacker != 0 || isTriggerHurt))
	{
		time = 0.1;
	}
	
	CreateTimer(time, Timer_RespawnPlayer, GetClientUserId(client));
	g_flLastRespawnTime[client] = GetGameTime();
}

public Action Timer_RespawnPlayer(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	
	if (!CheckCommandAccess(client, "", ADMFLAG_RESERVATION)) {
		return Plugin_Handled;
	}
	
	if (client > 0 && IsClientInGame(client) && !IsPlayerAlive(client))
	{
		TF2_RespawnPlayer(client);
	}
	
	return Plugin_Handled;
}

void DisplayRespawnHUDMessages(int client)
{
	if (!xVip_IsVip(client)) {
		return;
	}
	
	char text[256];
	FormatEx(text, sizeof(text), "%T", "Call Medic To Respawn", client);
	
	SetHudTextParams(-1.0, 0.7, 5.0, 255, 255, 255, 255);
	ShowSyncHudText(client, g_hHUDSynchronizer, text);
}

bool IsRespawnAllowed()
{
	return IsRespawnAllowedOnGameType(GetCurrentGameType()) && IsRespawnAllowedOnRoundState(GameRules_GetRoundState());
}

TFGameType GetCurrentGameType()
{
	return view_as<TFGameType>(GameRules_GetProp("m_nGameType"));
}

bool IsRespawnAllowedOnGameType(TFGameType gameType)
{
	return gameType != TFGame_Arena && gameType != TFGame_MannVsMachine;
}

bool IsRespawnAllowedOnRoundState(RoundState roundState)
{
	return roundState != RoundState_TeamWin && roundState != RoundState_Stalemate;
}
public void OnClientDisconnect(int client)
{
	g_flLastRespawnTime[client] = 0.0;
	g_iRespawnMode[client] = RespawnMode_PressingE;
	g_bZatoichi[client] = false;
}

void DebugPrint(const char[] message, any ...)
{
	if (g_cvDebug.BoolValue)
	{
		char out[1024];
		VFormat(out, sizeof(out), message, 2);
		PrintToServer(out);
	}
}