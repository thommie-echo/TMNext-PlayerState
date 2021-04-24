#name "Data Manager"
#author "AR_Thommie"
#category "Aurora"

#include "AR_Data.as"

[Setting name="Write data to file"]
bool WriteToFile = true;

[Setting name="Write small log"]
bool WriteToLog = false;


sTMData@ TMData;

void Main() {
	@TMData = sTMData();
	TMData.Update(null);
}

void Render()
{
	if(TMData !is null)
	{
		sTMData@ previous = TMData;
		
		@TMData = sTMData();
		TMData.Update(previous);
		TMData.Compare(previous);
		if(WriteToFile)
			TMData.WriteToFile();
		
		if(WriteToLog)
		{
			if(TMData.dEventInfo.CheckpointChange)
				print("checkpoint change: " + TMData.dPlayerInfo.NumberOfCheckpointsPassed + "/" + (TMData.dMapInfo.NumberOfCheckpoints + 1));
			if(TMData.dEventInfo.PlayerStateChange)
				print("state: " + EPlayerStateToString(TMData.PlayerState) + " at: " + TMData.dPlayerInfo.CurrentRaceTime);
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
		}
	}
	
}