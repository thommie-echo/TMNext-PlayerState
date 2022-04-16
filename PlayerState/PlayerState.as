#name "PlayerState"
#author "AR_Thommie"
#category "Aurora"

[Setting name="Write small log"]
bool WriteToLog = false;


PlayerState::sTMData@ TMData;


void Main() {
	@TMData = PlayerState::sTMData();
	TMData.Update(null);
}

void Render()
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

