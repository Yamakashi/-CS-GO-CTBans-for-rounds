public Action DatabaseConnect()
{
	char sError[512];
	Databases = SQL_Connect("Yamakashi_CTBans", true, sError, sizeof(sError));
	if(Databases == INVALID_HANDLE)
	{
		LogError("[ X CTBANS X ] Error podczas połączenia z bazą: %s", sError);
		g_iDatabase = 0;
	}
	else if(g_iDatabase < 1)
	{
		g_iDatabase++;
		char Query_CTBans1[1024], Query_CTBans2[1024];
		Format(Query_CTBans1, sizeof(Query_CTBans1), "CREATE TABLE IF NOT EXISTS `%s` (`SteamID` VARCHAR(64) NOT NULL, `Nick` VARCHAR(64) NOT NULL, `Rounds` INT NOT NULL, UNIQUE KEY `SteamID` (`SteamID`)) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_polish_ci;", Table);
		Format(Query_CTBans2, sizeof(Query_CTBans2), "CREATE TABLE IF NOT EXISTS `%s` (`Id` INT UNSIGNED AUTO_INCREMENT, `Nick` VARCHAR(64) NOT NULL, `SteamID` VARCHAR(64) NOT NULL, `Rounds` INT NOT NULL, `Reason` VARCHAR(64) NOT NULL, `Admin` VARCHAR(64) NOT NULL, `Admin_SteamID` VARCHAR(64) NOT NULL, `Timeleft` INT NOT NULL, `Map` VARCHAR(64) NOT NULL, `Date` VARCHAR(64) NOT NULL, PRIMARY KEY (`Id`))", Table_Log);
		
		SQL_LockDatabase(Databases);
		SQL_FastQuery(Databases, Query_CTBans1);
		SQL_FastQuery(Databases, Query_CTBans2);
		SQL_UnlockDatabase(Databases);
		DatabaseConnect();
	}
}

public Action PrepareLoadData(int client)
{
	if(!IsValidClient(client)) return Plugin_Continue;
		
	if (!g_iDatabase)
		PrintToChat(client, "%s Wystąpił błąd!", PluginTag);
	else
	{
		char Query_CTBans[1024], sAuthId[64];
		GetClientAuthId(client, AuthId_Steam2, sAuthId, sizeof(sAuthId));
		Format(Query_CTBans, sizeof(Query_CTBans), "SELECT `Rounds` FROM `%s` WHERE `SteamID` LIKE '%s';", Table, sAuthId);
		SQL_TQuery(Databases, LoadData, Query_CTBans, client);
	}
	return Plugin_Continue;
}

public void LoadData(Handle owner, Handle query, const char[] error, any client)
{
	if(query == INVALID_HANDLE)
	{
		LogError("[ X CTBANS X ] Error podczas wczytywania danych: %s", error);
		return;
	}
	if(SQL_GetRowCount(query))
		while(SQL_MoreRows(query))
		{
			while(SQL_FetchRow(query))
				g_iBanRounds[client] = SQL_FetchInt(query, 0);
		}
}

public Action InsertCTBan(int client, int rounds)
{
	if(!g_iDatabase) return Plugin_Continue;
	if(!IsValidClient(client)) return Plugin_Continue;
	
	char Query_CTBans[1024], sAuthId[64], Nick[MAX_NAME_LENGTH], Safe_Nick[MAX_NAME_LENGTH * 2];
	GetClientName(client, Nick, MAX_NAME_LENGTH);
	SQL_EscapeString(Databases, Nick, Safe_Nick, sizeof(Safe_Nick));
	GetClientAuthId(client, AuthId_Steam2, sAuthId, sizeof(sAuthId));
	Format(Query_CTBans, sizeof(Query_CTBans), "INSERT INTO `%s` (`SteamID`, `Nick`, `Rounds`) VALUES ('%s', N'%s', '%d') ON DUPLICATE KEY UPDATE `Rounds`=VALUES(`Rounds`);", Table, sAuthId, Safe_Nick, rounds);
	SQL_TQuery(Databases, InsertCTBan_Handler, Query_CTBans, client);
	return Plugin_Continue;
}

public Action InsertCTBanLog(int client, int banned, int rounds, char[] reason)
{
	if(!g_iDatabase) return Plugin_Continue;
	if(!IsValidClient(client)) return Plugin_Continue;
	if(!IsValidClient(banned)) return Plugin_Continue;
	
	char Query_CTBans[1024], sAuthId[64], sAuthId2[64], Nick[MAX_NAME_LENGTH], Safe_Nick[MAX_NAME_LENGTH * 2], Nick2[MAX_NAME_LENGTH], Safe_Nick2[MAX_NAME_LENGTH * 2];
	GetClientName(client, Nick, MAX_NAME_LENGTH);
	GetClientName(banned, Nick2, MAX_NAME_LENGTH);
	SQL_EscapeString(Databases, Nick, Safe_Nick, sizeof(Safe_Nick));
	SQL_EscapeString(Databases, Nick2, Safe_Nick2, sizeof(Safe_Nick2));
	GetClientAuthId(client, AuthId_Steam2, sAuthId, sizeof(sAuthId));
	GetClientAuthId(banned, AuthId_Steam2, sAuthId2, sizeof(sAuthId2));
	char sCreateDate[32];
	FormatTime(sCreateDate, sizeof(sCreateDate), "%k:%M %d.%m.%Y", GetTime());
	Format(Query_CTBans, sizeof(Query_CTBans), "INSERT INTO `%s` (`Nick`, `SteamID`, `Rounds`, `Reason`, `Admin`, `Admin_SteamID`, `Timeleft`, `Map`, `Date`) VALUES (N'%s', '%s', '%d', '%s', N'%s', '%s', '%d', '%s', '%s')", Table_Log, Safe_Nick2, sAuthId2, rounds, reason, Safe_Nick, sAuthId, g_iBanRounds[banned], g_sCurrentMap, sCreateDate);
	SQL_TQuery(Databases, InsertCTBan_Handler, Query_CTBans, client);
	return Plugin_Continue;
}

public Action DeleteCTBan(int client)
{
	if(!g_iDatabase) return Plugin_Continue;
	if(!IsValidClient(client)) return Plugin_Continue;
	
	char Query_CTBans[1024], Query_CTBans2[1024], sAuthId[64];
	GetClientAuthId(client, AuthId_Steam2, sAuthId, sizeof(sAuthId));
	Format(Query_CTBans, sizeof(Query_CTBans), "DELETE FROM `%s` WHERE `SteamID`='%s'", Table, sAuthId);
	Format(Query_CTBans2, sizeof(Query_CTBans2), "UPDATE `%s` SET `Timeleft`='-1' WHERE `SteamID`='%s' AND `Timeleft`>='0'", Table_Log, sAuthId);
	SQL_TQuery(Databases, DeleteCTBan_Handler, Query_CTBans, client);
	SQL_TQuery(Databases, DeleteCTBan_Handler, Query_CTBans2, client);
	return Plugin_Continue;
}

public Action UpdateBan(int client)
{
	if(!g_iDatabase) return Plugin_Continue;
	if(!IsValidClient(client)) return Plugin_Continue;
	
	char Query_CTBans[1024], Query_CTBans2[1024], sAuthId[64];
	GetClientAuthId(client, AuthId_Steam2, sAuthId, sizeof(sAuthId));
	Format(Query_CTBans, sizeof(Query_CTBans), "UPDATE `%s` SET `Rounds`='%d' WHERE `SteamID`='%s'", Table, g_iBanRounds[client], sAuthId);
	Format(Query_CTBans2, sizeof(Query_CTBans2), "UPDATE `%s` SET `Timeleft`='%d' WHERE `SteamID`='%s' AND `Timeleft`>='0'", Table_Log, g_iBanRounds[client], sAuthId);
	SQL_TQuery(Databases, UpdateCTBan_Handler, Query_CTBans, client);
	SQL_TQuery(Databases, UpdateCTBan_Handler, Query_CTBans2, client);
	return Plugin_Continue;
}

public void UpdateCTBan_Handler(Handle owner, Handle query, const char[] error, any client)
{
	if(query == INVALID_HANDLE)
	{
		LogError("[ X CTBANS X ] Error podczas updatu danych: %s", error);
		return;
	}
}

public void InsertCTBan_Handler(Handle owner, Handle query, const char[] error, any client)
{
	if(query == INVALID_HANDLE)
	{
		LogError("[ X CTBANS X ] Error podczas dodawania bana: %s", error);
		return;
	}
}

public void DeleteCTBan_Handler(Handle owner, Handle query, const char[] error, any client)
{
	if(query == INVALID_HANDLE)
	{
		LogError("[ X CTBANS X ] Error podczas usuwania bana: %s", error);
		return;
	}
}