[Setting name="Write small log"]
bool WriteToLog = false;

[Setting name="Render debug menu"]
bool RenderDebug = false;

PlayerState::sTMData@ TMData;

void Main() {
	@TMData = PlayerState::sTMData();
	TMData.Update(null);
}


void Update(float dt)
{
	
	if(TMData !is null)
	{
		PlayerState::sTMData@ previous = TMData;
		
		@TMData = PlayerState::sTMData();
		TMData.Update(previous);
		TMData.Compare(previous);

		
		if(WriteToLog)
		{
			if(TMData.dEventInfo.CheckpointChange)
				print("checkpoint change: " + TMData.dPlayerInfo.NumberOfCheckpointsPassed + "/" + (TMData.dMapInfo.NumberOfCheckpoints + 1));
			if(TMData.dEventInfo.PlayerStateChange)
				print("state: " + PlayerState::EPlayerStateToString(TMData.PlayerState) + " at: " + TMData.dPlayerInfo.CurrentRaceTime);
			if(TMData.dEventInfo.MapChange)
				print("MapChange: " + TMData.dMapInfo.EdChallengeId);
			if(TMData.dEventInfo.PauseChange)
				print("PauseChange");
			if(TMData.dEventInfo.ServerChange)
				print("ServerChange: " + TMData.dServerInfo.ServerLogin);
			if(TMData.dEventInfo.GameModeChange)
				print("GameModeChange: " + TMData.dServerInfo.CurGameModeStr);
			if(TMData.dEventInfo.HandicapChange)
				print("HandicapChange");
			if(TMData.dEventInfo.LapChange)
				print("Lap change: " + (TMData.dPlayerInfo.CurrentLapNumber + 1) + "/" + TMData.dMapInfo.TMObjective_NbLaps + " at: " + TMData.dPlayerInfo.LapStartTime);
			if(TMData.dEventInfo.FinishRun)
				print("Finished at: " + TMData.dPlayerInfo.EndTime);
			if(TMData.dEventInfo.bRespawnChange)
			{
				if(TMData.dEventInfo.bRespawned)
					print("Player respawned at time: " + TMData.dPlayerInfo.RespawnTime);
				else
					print("Player regained control after respawn");
			}
				
		}
	}
	
}

namespace PlayerState
{
	sTMData@ GetRaceData()
	{
		return TMData;
	}
}

void Render()
{
	if(!RenderDebug)
		return;
	
	if(UI::CollapsingHeader("TMData"))
	{
		UI::BeginTable("TMData", 2);
		
		UI::TableNextColumn();
		UI::Text("IsPaused");
		UI::TableNextColumn();
		UI::Text("" + TMData.IsPaused);
		
		UI::TableNextColumn();
		UI::Text("IsMultiplayer");
		UI::TableNextColumn();
		UI::Text("" + TMData.IsMultiplayer);
		
		UI::TableNextColumn();
		UI::Text("IsSpectator");
		UI::TableNextColumn();
		UI::Text("" + TMData.IsSpectator);
		
		UI::TableNextColumn();
		UI::Text("UpdateNumber");
		UI::TableNextColumn();
		UI::Text("" + TMData.UpdateNumber);
		
		UI::TableNextColumn();
		UI::Text("PlayerState");
		UI::TableNextColumn();
		UI::Text("" + PlayerState::EPlayerStateToString(TMData.PlayerState));
		UI::EndTable();
	}
	
	if(UI::CollapsingHeader("sGameInfo"))
	{
		UI::BeginTable("sGameInfo", 2);
		
		UI::TableNextColumn();
		UI::Text("Period");
		UI::TableNextColumn();
		UI::Text("" + TMData.dGameInfo.Period);
		
		UI::TableNextColumn();
		UI::Text("GameTime");
		UI::TableNextColumn();
		UI::Text("" + TMData.dGameInfo.GameTime);
		UI::EndTable();
	}
	
	if(UI::CollapsingHeader("sServerInfo"))
	{
		UI::BeginTable("sServerInfo", 2);
		
		UI::TableNextColumn();
		UI::Text("PlayerCount");
		UI::TableNextColumn();
		UI::Text("" + TMData.dServerInfo.PlayerCount);
		
		UI::TableNextColumn();
		UI::Text("ServerName");
		UI::TableNextColumn();
		UI::Text("" + TMData.dServerInfo.ServerName);
		
		UI::TableNextColumn();
		UI::Text("ServerLogin");
		UI::TableNextColumn();
		UI::Text("" + TMData.dServerInfo.ServerLogin);
		
		UI::TableNextColumn();
		UI::Text("CurGameModeStr");
		UI::TableNextColumn();
		UI::Text("" + TMData.dServerInfo.CurGameModeStr);
		UI::EndTable();
	}
	
	if(UI::CollapsingHeader("sMapInfo"))
	{
		UI::BeginTable("sMapInfo", 2);
		
		UI::TableNextColumn();
		UI::Text("EdChallengeId");
		UI::TableNextColumn();
		UI::Text("" + TMData.dMapInfo.EdChallengeId);
		
		UI::TableNextColumn();
		UI::Text("MapName");
		UI::TableNextColumn();
		UI::Text("" + TMData.dMapInfo.MapName);
		
		UI::TableNextColumn();
		UI::Text("AuthorLogin");
		UI::TableNextColumn();
		UI::Text("" + TMData.dMapInfo.AuthorLogin);
		
		UI::TableNextColumn();
		UI::Text("AuthorNickName");
		UI::TableNextColumn();
		UI::Text("" + TMData.dMapInfo.AuthorNickName);
		
		UI::TableNextColumn();
		UI::Text("MapType");
		UI::TableNextColumn();
		UI::Text("" + TMData.dMapInfo.MapType);
		
		UI::TableNextColumn();
		UI::Text("MapStyle");
		UI::TableNextColumn();
		UI::Text("" + TMData.dMapInfo.MapStyle);
		
		UI::TableNextColumn();
		UI::Text("TMObjective_NbLaps");
		UI::TableNextColumn();
		UI::Text("" + TMData.dMapInfo.TMObjective_NbLaps);
		
		UI::TableNextColumn();
		UI::Text("TMObjective_IsLapRace");
		UI::TableNextColumn();
		UI::Text("" + TMData.dMapInfo.TMObjective_IsLapRace);
		
		UI::TableNextColumn();
		UI::Text("NumberOfCheckpoints");
		UI::TableNextColumn();
		UI::Text("" + TMData.dMapInfo.NumberOfCheckpoints);
		
		UI::TableNextColumn();
		UI::Text("StartCPNumber");
		UI::TableNextColumn();
		UI::Text("" + TMData.dMapInfo.StartCPNumber);
		
		UI::TableNextColumn();
		UI::Text("bIsMultiLap");
		UI::TableNextColumn();
		UI::Text("" + TMData.dMapInfo.bIsMultiLap);
		
		UI::TableNextColumn();
		UI::Text("MapLandmarks Length");
		UI::TableNextColumn();
		UI::Text("" + TMData.dMapInfo.MapLandmarks.Length);
		UI::EndTable();
	}
	
	if(UI::CollapsingHeader("sMLData"))
	{
		UI::BeginTable("sMLData", 2);
		
		UI::TableNextColumn();
		UI::Text("PlayerData");
		UI::TableNextColumn();
		UI::Text("" + TMData.dMLData.PlayerData);
		
		UI::TableNextColumn();
		UI::Text("AllPlayerData");
		UI::TableNextColumn();
		UI::Text("" + TMData.dMLData.AllPlayerData);
		
		UI::TableNextColumn();
		UI::Text("NumCPs");
		UI::TableNextColumn();
		UI::Text("" + TMData.dMLData.NumCPs);
		
		UI::TableNextColumn();
		UI::Text("PlayerLastCheckpointTime");
		UI::TableNextColumn();
		UI::Text("" + TMData.dMLData.PlayerLastCheckpointTime);
		
		UI::TableNextColumn();
		UI::Text("StartTime");
		UI::TableNextColumn();
		UI::Text("" + TMData.dMLData.StartTime);
		
		UI::TableNextColumn();
		UI::Text("CurrentRaceTime");
		UI::TableNextColumn();
		UI::Text("" + TMData.dMLData.CurrentRaceTime);
		UI::EndTable();
	}
	
	if(UI::CollapsingHeader("sPlayerInfo"))
	{
		UI::BeginTable("sPlayerInfo", 2);
		
		UI::TableNextColumn();
		UI::Text("EndTime");
		UI::TableNextColumn();
		UI::Text("" + TMData.dPlayerInfo.EndTime);
		
		UI::TableNextColumn();
		UI::Text("NumberOfCheckpointsPassed");
		UI::TableNextColumn();
		UI::Text("" + TMData.dPlayerInfo.NumberOfCheckpointsPassed);
		
		UI::TableNextColumn();
		UI::Text("CurrentLapNumber");
		UI::TableNextColumn();
		UI::Text("" + TMData.dPlayerInfo.CurrentLapNumber);
		
		UI::TableNextColumn();
		UI::Text("CurrentRaceTime");
		UI::TableNextColumn();
		UI::Text("" + TMData.dPlayerInfo.CurrentRaceTime);
		
		UI::TableNextColumn();
		UI::Text("LapStartTime");
		UI::TableNextColumn();
		UI::Text("" + TMData.dPlayerInfo.LapStartTime);
		
		UI::TableNextColumn();
		UI::Text("LatestCPTime");
		UI::TableNextColumn();
		UI::Text("" + TMData.dPlayerInfo.LatestCPTime);
		
		UI::TableNextColumn();
		UI::Text("StartTime");
		UI::TableNextColumn();
		UI::Text("" + TMData.dPlayerInfo.StartTime);
		
		UI::TableNextColumn();
		UI::Text("Speed");
		UI::TableNextColumn();
		UI::Text("" + TMData.dPlayerInfo.Speed);
		
		UI::TableNextColumn();
		UI::Text("Login");
		UI::TableNextColumn();
		UI::Text("" + TMData.dPlayerInfo.Login);
		
		UI::TableNextColumn();
		UI::Text("Name");
		UI::TableNextColumn();
		UI::Text("" + TMData.dPlayerInfo.Name);
		
		UI::TableNextColumn();
		UI::Text("LatestCheckpointLandmarkIndex");
		UI::TableNextColumn();
		UI::Text("" + TMData.dPlayerInfo.LatestCheckpointLandmarkIndex);
		
		UI::TableNextColumn();
		UI::Text("TrustClientSimu_ServerOverrideCount");
		UI::TableNextColumn();
		UI::Text("" + TMData.dPlayerInfo.TrustClientSimu_ServerOverrideCount);
		
		UI::TableNextColumn();
		UI::Text("RespawnTime");
		UI::TableNextColumn();
		UI::Text("" + TMData.dPlayerInfo.RespawnTime);
		
		UI::TableNextColumn();
		UI::Text("NbRespawnsRequested");
		UI::TableNextColumn();
		UI::Text("" + TMData.dPlayerInfo.NbRespawnsRequested);
		UI::EndTable();
	}
}



