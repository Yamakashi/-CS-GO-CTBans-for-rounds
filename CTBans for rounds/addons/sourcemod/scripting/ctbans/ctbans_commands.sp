public Action CTBan_CMD(int client, int args)
{
	if(!IsValidClient(client))
		return Plugin_Continue;
		
	char sArg1[64], sArg2[32], sArg3[128], sAuthId[64];
	GetCmdArg(1, sArg1, sizeof(sArg1));
	GetCmdArg(2, sArg2, sizeof(sArg2));
	GetCmdArg(3, sArg3, sizeof(sArg3));
	
	int rounds = StringToInt(sArg2);
	int target = FindTarget(client, sArg1);

	if(g_iBanRounds[target] > 0)
	{
		CPrintToChat(client, "%s {darkred}Niepowodzenie!{lightred} Ten gracz posiada już CTBana.", PluginTag);
		return Plugin_Handled;
	}
	if(args < 3)
	{
		CPrintToChat(client, "%s Poprawne użycie komendy: {lime}!ctban <nick> <rundy> <powod>{default}.", PluginTag);
		PrintToConsole(client, "Poprawne użycie komendy: !ctban <nick> <rundy> <powod>.");
		return Plugin_Handled;
	}
	if(!IsValidClient(target))
	{
		CPrintToChat(client, "%s {darkred}Niepowodzenie!{lightred} Nie odnaleziono wybranego gracza.", PluginTag);
		return Plugin_Handled;
	}
	if(rounds == 0)
	{
		PrintToConsole(client, "%s Liczba rund nie moze wynosic 0", PluginTag);
		CPrintToChat(client, "%s {darkred}Niepowodzenie!{lightred} Liczba rund nie moze wynosic {lime}0", PluginTag);
		return Plugin_Handled;
	}
	
	GetClientAuthId(target, AuthId_Steam2, sAuthId, sizeof(sAuthId));
	CPrintToChatAll("%s Administrator {lime}%N{default} nadał CTBana graczowi {lime}%N{default} na {lightred}%d{default} rund z powodem {lightred}%s{default}.", PluginTag, client, target, rounds, sArg3);
	LogToFileEx(g_sLogFile, "[ CTBANS ]	BAN	| %N (%s) otrzymał bana na '%d' rund z powodem '%s'", target, sAuthId, rounds, sArg3);
	g_iBanRounds[target] = rounds;
	if(GetClientTeam(target) == CS_TEAM_CT)
		ChangeTeam(target);
	InsertCTBan(target, rounds);
	InsertCTBanLog(client, target, rounds, sArg3);
	return Plugin_Handled;
}

public Action UnCTBan_CMD(int client, int args)
{
	if(!IsValidClient(client))
		return Plugin_Continue;
	char sArg1[64], sAuthId[64], sAuthId2[64];
	GetCmdArg(1, sArg1, sizeof(sArg1));
	int target = FindTarget(client, sArg1);
	GetClientAuthId(client, AuthId_Steam2, sAuthId, sizeof(sAuthId));
	GetClientAuthId(target, AuthId_Steam2, sAuthId2, sizeof(sAuthId2));
	
	if(g_iBanRounds[target] < 0)
	{
		CPrintToChat(client, "%s {darkred}Niepowodzenie!{lightred} Ten gracz nie posiada CTBana", PluginTag);
		return Plugin_Handled;
	}
	if(!IsValidClient(target))
	{
		CPrintToChat(client, "%s {darkred}Niepowodzenie!{lightred} Nie odnaleziono wybranego gracza.", PluginTag);
		return Plugin_Handled;
	}
	g_iBanRounds[target] = -1;
	CPrintToChatAll("%s Administrator {lime}%N{default} zdjął CTBana graczowi {lightred}%N{default}.", PluginTag, client, target);
	LogToFileEx(g_sLogFile, "[ CTBANS ] UNBAN | %N (%s) zdjął CTBana graczowi %N (%s) .", client, sAuthId, target, sAuthId2);
	DeleteCTBan(target);
	return Plugin_Handled;
}

public Action Status_CMD(int client, int args)
{
	if(GetUserFlagBits(client) & ADMFLAG_GENERIC)
	{
		char sArg1[64];
		GetCmdArg(1, sArg1, sizeof(sArg1));
		int target = FindTarget(client, sArg1);
		
		if(!IsValidClient(target))
		{
			CPrintToChat(client, "%s {darkred}Niepowodzenie!{lightred} Nie odnaleziono wybranego gracza.", PluginTag);
			return Plugin_Handled;
		}
	
		if(g_iBanRounds[target] < 0)
		{
			CPrintToChat(client, "%s {darkred}Niepowodzenie! {lightred}Ten gracz nie posiada CTBana.", PluginTag);
			return Plugin_Handled;
		}
		char Query_CTBans[1024], sAuthId[64];
		GetClientAuthId(target, AuthId_Steam2, sAuthId, sizeof(sAuthId));
		Format(Query_CTBans, sizeof(Query_CTBans), "SELECT `Nick`, `Rounds`, `Reason`, `Admin`, `Timeleft`, `Map`, `Date` FROM `%s` WHERE `SteamID`='%s' AND `Timeleft`>=0", Table_Log, sAuthId);
		SQL_TQuery(Databases, SQL_Status_Handler, Query_CTBans, client);
	}
	else
	{
		if(g_iBanRounds[client] < 0)
		{
			CPrintToChat(client, "%s Nie posiadasz żadnego CTBana", PluginTag);
			return Plugin_Handled;
		}
		char Query_CTBans[1024], sAuthId[64];
		GetClientAuthId(client, AuthId_Steam2, sAuthId, sizeof(sAuthId));
		Format(Query_CTBans, sizeof(Query_CTBans), "SELECT `Rounds`, `Reason`, `Admin`, `Timeleft`, `Map`, `Date` FROM `%s` WHERE `SteamID`='%s' AND `Timeleft`>=0", Table_Log, sAuthId);
		SQL_TQuery(Databases, SQL_Status_Handler2, Query_CTBans, client);
	}
	return Plugin_Handled;
}

public void SQL_Status_Handler(Handle owner, Handle query, const char[] error, any client)
{
	if(query == INVALID_HANDLE)
	{
		LogError("[ X CTBANS X ] Error podczas wyswietlania: %s", error);
		return;
	}
	
	char sName[MAX_NAME_LENGTH], sAdmin[MAX_NAME_LENGTH], sReason[128], sBuffer[1024], sMap[128], sDate[128];
	if(SQL_FetchRow(query))
	{
		SQL_FetchString(query, 0, sName, sizeof(sName));
		int rounds = SQL_FetchInt(query, 1);
		SQL_FetchString(query, 2, sReason, sizeof(sReason));
		SQL_FetchString(query, 3, sAdmin, sizeof(sAdmin));
		int timeleft = SQL_FetchInt(query, 4);
		SQL_FetchString(query, 5, sMap, sizeof(sMap));
		SQL_FetchString(query, 6, sDate, sizeof(sDate));
		
		Panel status_target = new Panel();
		Format(sBuffer, sizeof(sBuffer), "[ # Jailbreak :: Informacje na temat CTBana # ]\n ");
		Format(sBuffer, sizeof(sBuffer), "%s\n Nick Gracza: %s", sBuffer, sName);
		Format(sBuffer, sizeof(sBuffer), "%s\n Nick Admina: %s", sBuffer, sAdmin);
		Format(sBuffer, sizeof(sBuffer), "%s\n Powód Bana: %s", sBuffer, sReason);
		Format(sBuffer, sizeof(sBuffer), "%s\n Długość Bana: %d rund", sBuffer, rounds);
		Format(sBuffer, sizeof(sBuffer), "%s\n Pozostało: %d rund", sBuffer, timeleft);
		Format(sBuffer, sizeof(sBuffer), "%s\n Mapa: %s", sBuffer, sMap);
		Format(sBuffer, sizeof(sBuffer), "%s\n Data i Godzina: %s\n ", sBuffer, sDate);
		status_target.SetTitle(sBuffer);
		status_target.DrawItem("»Zamknij");
		status_target.Send(client, Status_Handler, 30);
		delete status_target;
	}
	else
		CPrintToChat(client, "%s {darkred}Niepowodzenie!{lightred} Nie odnaleziono CTBana tego gracza.", PluginTag);
}

public int Status_Handler(Menu menu, MenuAction action, int client, int Position)
{
	if(action == MenuAction_Select)
		menu.Close();
}

public void SQL_Status_Handler2(Handle owner, Handle query, const char[] error, any client)
{
	if(query == INVALID_HANDLE)
	{
		LogError("[ X CTBANS X ] Error podczas wyswietlania informacji: %s", error);
		return;
	}
	
	char sAdmin[MAX_NAME_LENGTH], sReason[128], sBuffer[1024], sMap[128], sDate[128];
	if(SQL_FetchRow(query))
	{
		int rounds = SQL_FetchInt(query, 0);
		SQL_FetchString(query, 1, sReason, sizeof(sReason));
		SQL_FetchString(query, 2, sAdmin, sizeof(sAdmin));
		int timeleft = SQL_FetchInt(query, 3);
		SQL_FetchString(query, 4, sMap, sizeof(sMap));
		SQL_FetchString(query, 5, sDate, sizeof(sDate));
		
		Panel status_target2 = new Panel();
		Format(sBuffer, sizeof(sBuffer), "[ # Jailbreak :: Informacje na temat CTBana # ]\n ");
		Format(sBuffer, sizeof(sBuffer), "%s\n Nick Gracza: %N", sBuffer, client);
		Format(sBuffer, sizeof(sBuffer), "%s\n Nick Admina: %s", sBuffer, sAdmin);
		Format(sBuffer, sizeof(sBuffer), "%s\n Powód Bana: %s", sBuffer, sReason);
		Format(sBuffer, sizeof(sBuffer), "%s\n Długość Bana: %d rund", sBuffer, rounds);
		Format(sBuffer, sizeof(sBuffer), "%s\n Pozostało: %d rund", sBuffer, timeleft);
		Format(sBuffer, sizeof(sBuffer), "%s\n Mapa: %s", sBuffer, sMap);
		Format(sBuffer, sizeof(sBuffer), "%s\n Data i Godzina: %s\n ", sBuffer, sDate);
		status_target2.SetTitle(sBuffer);
		status_target2.DrawItem("»Zamknij");
		status_target2.Send(client, Status_Handler2, 30);
		delete status_target2;
	}
	else
		CPrintToChat(client, "%s {darkred}Niepowodzenie!{lightred} Nie odnaleziono CTBana.", PluginTag);
}

public int Status_Handler2(Menu menu, MenuAction action, int client, int Position)
{
	if(action == MenuAction_Select)
		menu.Close();
}

