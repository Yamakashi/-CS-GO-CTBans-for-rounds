public Action CheckBan(int client)
{
	if(g_iBanRounds[client] > 0)
		UpdateBan(client);
	else if(g_iBanRounds[client] == 0)
	{
		DeleteCTBan(client);
		g_iBanRounds[client] = -1;
		CPrintToChat(client, "%s {green}Gratulacje! {lime}Twój {lightred}CTBan{lime} się skończył.", PluginTag);
		CPrintToChatAll("%s Graczowi {lightred}%N{default} skończył się {lightred}CTBan{default}.", PluginTag, client);
		ClientCommand(client, "playgamesound Music.StopAllMusic");
		PrecacheSound("ctbans_yamakashi/ban_end.mp3", true);
		EmitSoundToClient(client, "ctbans_yamakashi/ban_end.mp3", _, _, _, _, 1.0);	
	}
}

public void ChangeTeam(int client)
{
	if(!IsValidClient(client))
		return;
		
	ForcePlayerSuicide(client);
	ChangeClientTeam(client, CS_TEAM_T);
	if(g_cvRespAndTeleport.BoolValue)
	{
		CS_RespawnPlayer(client);
		int RandomTT = 0;
		for(int i = 1; i <= MaxClients; i++)
			if(IsPlayerAlive(i))
				if(GetClientTeam(i) == CS_TEAM_T)
				{
					RandomTT = i;
					break;
				}
	
		if(RandomTT)
		{
			GetClientAbsOrigin(RandomTT, g_fPos);
			g_fPos[2] = g_fPos[2] + 5;
			TeleportEntity(client, g_fPos, NULL_VECTOR, NULL_VECTOR);
		}
	}	
}

public void Reset(int client)
{
	g_iBanRounds[client] = -1;
}

void UTIL_TeamMenu(int client)
{
	int clients[1];
	Handle hBfWritePack;
	clients[0] = client;
	hBfWritePack = StartMessage("VGUIMenu", clients, 1);

	if (GetUserMessageType() == UM_Protobuf)
	{
		PbSetString(hBfWritePack, "name", "team");
		PbSetBool(hBfWritePack, "show", true);
	}
	else
	{
		BfWriteString(hBfWritePack, "team");
		BfWriteByte(hBfWritePack, 1);
		BfWriteByte(hBfWritePack, 0);
	}

	EndMessage();
}

stock bool IsValidClient(int client)
{
	if(client <= 0 ) return false;
	if(client > MaxClients) return false;
	if(!IsClientConnected(client)) return false;
	if(IsFakeClient(client)) return false;
	return IsClientInGame(client);
}