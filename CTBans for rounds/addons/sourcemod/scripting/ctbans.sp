/* [ Includes ] */
#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <cstrike>

/* [ Compiler Options ] */
#pragma newdecls required
#pragma semicolon 1

/* [ Defines ] */
#define PluginTag 	"{darkred}[ {lightred}★{darkred} CTBANS {lightred}★ {darkred}]{default}"
#define Table		"ctbans"
#define Table_Log	"ctbans_logs"

/* [ ConVars ] */
ConVar g_cvRespAndTeleport;

/* [ Chars ] */
char g_sLogFile[256];
char g_sCurrentMap[256];

/* [ Integers ] */
int g_iBanRounds[MAXPLAYERS + 1];
int g_iDatabase = 0;

/* [ Handles ] */
Database Databases;

/* [ Floats ] */
float g_fPos[3];

/* [ Modules ] */
#include "ctbans/ctbans_commands.sp"
#include "ctbans/ctbans_databases.sp"
#include "ctbans/ctbans_helpers.sp"

/* [ Plugin Author and Information ] */
public Plugin myinfo =
{
	name = "[CS:GO] CTBans",
	author = "Yamakashi",
	description = "System CTBanów na rundy na serwery typu Jailbreak.",
	version = "1.3",
	url = "https://steamcommunity.com/id/yamakashisteam"
};

/* [ Plugin Startup ] */
public void OnPluginStart()
{
	/* [ ConVars ] */
	g_cvRespAndTeleport = CreateConVar("sm_ctban_resp_and_tp", "1", "Czy gracz po nadaniu CTBana ma być respiony i teleportowany do randomowego więźnia?");
	
	/* [ Commands ] */
	RegAdminCmd("sm_ctban", CTBan_CMD, ADMFLAG_GENERIC, "[CTBans] Dodanie CTBana");
	RegAdminCmd("sm_unctban", UnCTBan_CMD, ADMFLAG_GENERIC, "[CTBans] Usuwa CTBana");
	RegConsoleCmd("sm_status", Status_CMD, "[CTBans] Pokazuje status CTBana");
	AddCommandListener(Command_CheckJoin, "jointeam");
	
	/* [ Hooks ] */
	HookEvent("round_start", Event_RoundStart);
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
	HookEvent("player_team", Event_PlayerTeam, EventHookMode_Post);
	HookEvent("jointeam_failed", Event_JoinTeamFailed, EventHookMode_Pre);
	
	/* [ Database ] */
	DatabaseConnect();
	
	/* [ Translations ] */
	LoadTranslations("common.phrases");
	
	/* [ Check Player ] */
	for(int i = 1; i <= MaxClients; i++)
		if(IsValidClient(i))
			OnClientPutInServer(i);
			
	/* [ LogFile ] */
	char sDate[16];
	FormatTime(sDate, sizeof(sDate), "%Y-%m-%d", GetTime());
	BuildPath(Path_SM, g_sLogFile, sizeof(g_sLogFile), "logs/ctbans/%s.log", sDate);
}

/* [ Standart Actions ] */
public void OnMapStart()
{
	AutoExecConfig(true, "Yamakashi_CTBans", "yPlugins");
	AddFileToDownloadsTable("sound/ctbans_yamakashi/error.mp3");
	AddFileToDownloadsTable("sound/ctbans_yamakashi/ban_end.mp3");
	GetCurrentMap(g_sCurrentMap, 128);
}

public void OnClientPutInServer(int client)
{
	Reset(client);
	PrepareLoadData(client);
}

public void OnClientDisconnect(int client)
{
	char sAuthId[64];
	GetClientAuthId(client, AuthId_Steam2, sAuthId, sizeof(sAuthId));
	UpdateBan(client);
	if(g_iBanRounds[client] >= 0)
		LogToFileEx(g_sLogFile, "[ CTBANS ] WYJŚCIE	| %N (%s) przy wyjściu posiadał '%d' rund.", client, sAuthId, g_iBanRounds[client]);
	Reset(client);
}

public void OnMapEnd()
{
	for(int i = 1; i <= MaxClients; i++)
		if(IsValidClient(i))
			if(g_iBanRounds[i] >= 0)
			{
				char sAuthId[64];
				GetClientAuthId(i, AuthId_Steam2, sAuthId, sizeof(sAuthId));
				UpdateBan(i);
				LogToFileEx(g_sLogFile, "[ CTBANS ] WYJŚCIE	| %N (%s) przy wyjściu posiadał '%d' rund.", i, sAuthId, g_iBanRounds[i]);
			}
}

public void OnPluginEnd()
{
	for(int i = 1; i <= MaxClients; i++)
		if(IsValidClient(i))
			if(g_iBanRounds[i] >= 0)
			{
				char sAuthId[64];
				GetClientAuthId(i, AuthId_Steam2, sAuthId, sizeof(sAuthId));
				UpdateBan(i);
				LogToFileEx(g_sLogFile, "[ CTBANS ] WYJŚCIE	| %N (%s) przy wyjściu posiadał '%d' rund.", i, sAuthId, g_iBanRounds[i]);
			}
}

/* [ Events ] */
public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for(int i = 1; i <= MaxClients; i++)
		if(IsValidClient(i))
			if(g_iBanRounds[i] >= 0)
			{
				g_iBanRounds[i]--;
				CheckBan(i);
			}
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client)) return Plugin_Continue;

	if(GetClientTeam(client) == CS_TEAM_CT)
		if(g_iBanRounds[client] > 0)
		{
			ChangeTeam(client);
			CPrintToChat(client, "%s Posiadasz {lightred}CTBana{default}. Zostałeś automatycznie przeniesiony do TT.", PluginTag);
		}

	return Plugin_Continue;
}

public Action Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client)) return Plugin_Continue;
	
	int team = event.GetInt("team");
	bool disconnected = event.GetBool("disconnect");
	
	if (disconnected) return Plugin_Continue;
	
	if(team == CS_TEAM_CT && g_iBanRounds[client] > 0)
		if(IsPlayerAlive(client))
		{
			ChangeTeam(client);
			CPrintToChat(client, "%s Posiadasz {lightred}CTBana{default}. Zostałeś automatycznie przeniesiony do TT.", PluginTag);
		}
		
	return Plugin_Continue;
}

public Action Event_JoinTeamFailed(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(!IsValidClient(client)) return Plugin_Continue;
	
	int reason = event.GetInt("reason");

	if(reason == 0)
		if(g_iBanRounds[client] > 0)
		{
			ChangeClientTeam(client, CS_TEAM_T);
			CPrintToChat(client, "%s Posiadasz {lightred}CTBana{default}. Zostałeś automatycznie przeniesiony do TT.", PluginTag);
			return Plugin_Handled;
		}
		
	return Plugin_Continue;
}

/* [ Commands Listeners ] */
public Action Command_CheckJoin(int client, const char[] command, int args)
{
	char sJoinTeamString[5];
	GetCmdArg(1, sJoinTeamString, sizeof(sJoinTeamString));
	int team = StringToInt(sJoinTeamString);

	if((team == CS_TEAM_SPECTATOR || team == CS_TEAM_T))
	{

	}
	else if (g_iBanRounds[client] > 0)
	{
		if(GetClientTeam(client) != CS_TEAM_T)
			UTIL_TeamMenu(client);
		CPrintToChat(client, "%s {darkred}Niepowodzenie! {lightred}Posiadasz CTBana, więcej informacji pod {lime}!status{lightred}.", PluginTag);
		ClientCommand(client, "playgamesound Music.StopAllMusic");
		PrecacheSound("ctbans_yamakashi/error.mp3", true);
		EmitSoundToClient(client, "ctbans_yamakashi/error.mp3", _, _, _, _, 1.0);
		return Plugin_Stop;
	}

	return Plugin_Continue;
}
