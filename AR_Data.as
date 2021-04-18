//#name "TMData"
//#author "AR_Thommie"
//#category "Aurora"


string scriptFolder = "Scripts\\"; // c:/users/[username/OpenplanetNext/Script/
wstring Data_ML = ""; // Used to store the manialink to create UI and retrieve data
string Data_ML_FileName = "AR_DataML.txt"; // Filename of the manialink, should be in scriptFolder

// Used to load the manialink string in memory or return it if that's already been done
wstring GetDataML()
{
	if(Data_ML != "")
		return Data_ML;
	string File_To_Load = IO::FromDataFolder(scriptFolder + Data_ML_FileName);
	IO::File file(File_To_Load);
	file.Open(IO::FileMode::Read);
	
	string line = file.ReadLine();
	
	while(!file.EOF())
	{
		line = line + file.ReadLine();
	}
	Data_ML = line;
	return Data_ML;
}

// Returns the layer in the player's UI or creates it if there is none (i.e. after leaving the menu)
CGameUILayer@ GetLayer(wstring manialink, string id, CGameManiaAppPlayground@ UIMgr, CGamePlaygroundUIConfig@ clientUI)
{
	for(uint i = 0; i < clientUI.UILayers.Length; ++i) //This is used to check if we haven't already a layer with the same id, to avoid doubles
	{
		auto layer = cast<CGameUILayer>(clientUI.UILayers[i]);
		if(layer.AttachId == id)
			return layer;
	}


	auto injected_layer = UIMgr.UILayerCreate(); //This create a ML Layer in client UI
	injected_layer.AttachId = id; //We'll use AttachId as a reference to get organized in which UI is what
	injected_layer.ManialinkPage = manialink; //This is where the manialink code is
	clientUI.UILayers.Add(injected_layer); // We add the UI Layer to player's UI

	return injected_layer;// The function return the layer pointer to easily modify stuff in it
}

Json::Value SerializeVec3(vec3 vec)
{
	auto obj = Json::Object();
	obj["x"] = vec.x;
	obj["y"] = vec.y;
	obj["z"] = vec.z;
	return obj;
}

enum EPlayerState  // The below might not entirely be correct anymore
{
	EPlayerState_Menus = 0, // app.CurrentPlayground is null
	EPlayerState_Countdown, // [sPlayerInfo.CurrentRaceTime] < 0.0f && CSmPlayer.ScriptAPI.Post != EPost::CarDriver
	EPlayerState_Driving, // [sPlayerInfo.CurrentRaceTime] > 0.0f && CSmPlayer.ScriptAPI.Post == EPost::CarDriver
	EPlayerState_EndRace, // [sPlayerInfo.CurrentRaceTime] < 0.0f && Previous PlayerState was EPlayerState_Driving ~ unsure about both of these
	EPlayerState_Finished, // [sPlayerInfo.LatestCheckpointLandmarkIndex]  == [sMapInfo.NumberOfCheckpoints]      (CurrentPlayground.ReplayRecord.Ghosts > previous amount of ghosts)
	EPlayerState_Spectating, // [IsSpectator]
}

string EPlayerStateToString(EPlayerState State)
{
	if(State == EPlayerState::EPlayerState_Menus)
		return "EPlayerState_Menus";
	else if(State == EPlayerState::EPlayerState_Countdown)
		return "EPlayerState_Countdown";
	else if(State == EPlayerState::EPlayerState_Driving)
		return "EPlayerState_Driving";
	else if(State == EPlayerState::EPlayerState_EndRace)
		return "EPlayerState_EndRace";
	else if(State == EPlayerState::EPlayerState_Finished)
		return "EPlayerState_Finished";
	else if(State == EPlayerState::EPlayerState_Spectating)
		return "EPlayerState_Spectating";
	return "";
}

class sEventInfo
{
	bool EndRun; // True if the run of the player ends, either manually or by finishing [sTMData.PlayerState] [sPlayerInfo.TrustClientSimu_ServerOverrideCount]
	bool FinishRun; // Will coincide with EndRun, true the first tick when the player passes through the finish [sTMData.PlayerState] [sPlayerInfo.TrustClientSimu_ServerOverrideCount]
	bool MapChange; // True when changing a map, either from menu or a previous map [sMapInfo.EdChallengeId]
	bool PauseChange; // True when 'escape'-menu is open, only actually paused in singleplayer [sTMData.IsPaused]
	bool PlayerStateChange; // True when the PlayerState changes compared to the previous state [sTMData.PlayerState]
	bool ServerChange; // True when a server is joined [sServerInfo.ServerLogin]
	bool GameModeChange; // True when the gamemode has changed [sServerInfo.CurGameModeStr]
	bool HandicapChange; // True when any of the handicaps from [sPlayerInfo] change
	bool CheckpointChange; // True when the player passes through a checkpoint, or if the run is ended [sPlayerInfo.LatestCheckpointLandmarkIndex]
	
	Json::Value Serialize()
	{
		auto obj = Json::Object();
		obj["EndRun"] = EndRun;
		obj["FinishRun"] = FinishRun;
		obj["MapChange"] = MapChange;
		obj["PauseChange"] = PauseChange;
		obj["PlayerStateChange"] = PlayerStateChange;
		obj["ServerChange"] = ServerChange;
		obj["GameModeChange"] = GameModeChange;
		obj["HandicapChange"] = HandicapChange;
		obj["CheckpointChange"] = CheckpointChange;
		
		return obj;
	}
}

class sMLData
{
	string PlayerData; // NumCPs and all checkpoint times, separated by ",," and "," respectively
	string AllPlayerData; // Contains Login, the above, and CurrentRaceTime, players are separated by ",,,"
	int NumCPs; // Number of checkpoints the player has passed through, somehow changes to 1 when joining a server and not yet started playing, not serialized
	int PlayerLastCheckpointTime; // 0 or the most recent checkpoint time, not serialized

	Json::Value Serialize()
	{
		auto obj = Json::Object();
		obj["PlayerData"] = "" + PlayerData;
		obj["AllPlayerData"] = "" + AllPlayerData;
		
		return obj;
	}
}

class sTMData
{
	EPlayerState PlayerState;
	bool IsPaused; // [app.Network.PlaygroundClientScriptAPI.IsInGameMenuDisplayed]
	bool IsMultiplayer; // [app.PlaygroundScript] is null
	bool IsSpectator; // [PlaygroundClientScriptAPI.IsSpectator]
	uint UpdateNumber = 0;
	
	sGameInfo@ dGameInfo;
	sServerInfo@ dServerInfo;
	sMapInfo@ dMapInfo;
	sPlayerInfo@ dPlayerInfo;
	sEventInfo@ dEventInfo;
	sMLData@ dMLData; // Serialized on the second line, separately from the above
	
	sTMData()
	{
		@dGameInfo = sGameInfo(); // CurrentPlayground, PlaygroundClientScriptAPI
		@dServerInfo = sServerInfo(); // CurrentPlayground, ServerInfo
		@dMapInfo = sMapInfo(); // RootMap, CurrentPlayground
		@dPlayerInfo = sPlayerInfo(); // ScriptAPI, SmPlayer
		
		@dEventInfo = sEventInfo(); // contains the variables for events, all set in Compare() or InitialData()
		
		@dMLData = sMLData(); // Contains the information on checkpoints we get from manialink
	}
	
	EPlayerState GetPlayerState(CSmScriptPlayer@ ScriptAPI, sTMData@ previous)
	{
		if(IsSpectator) // See sTMData on how this is determined
			return EPlayerState::EPlayerState_Spectating;
		if(dMLData.NumCPs  > dMapInfo.NumberOfCheckpoints) // The only reliable way to get the number of cps a player has passed both online and offline
			return EPlayerState::EPlayerState_Finished;
		if(dPlayerInfo.StartTime > dGameInfo.GameTime) // StartTime is actually in the future when in countdown
			return EPlayerState::EPlayerState_Countdown;
		if(ScriptAPI.Post == EPost::CarDriver && previous.PlayerState == EPlayerState::EPlayerState_Countdown) // Only go to driving if you were counting down previously
			return EPlayerState::EPlayerState_Driving;
			
		if(previous !is null) // If in doubt, copy the prior version
			return previous.PlayerState;
			
		return EPlayerState::EPlayerState_Menus; // Not sure if this ever happens, but it only could happen on the first iteration or when no previous data is supplied (which you should always do if possible)
	}
	
	void Compare(sTMData@ previous)
	{			
		if(previous is null)
		{
			InitialData(); // Set up events in different way because we cannot compare to previous data
			return;
		}
		
		if(previous.dGameInfo.GameTime == dGameInfo.GameTime)
			UpdateNumber = previous.UpdateNumber;
		else
		{
			if(previous.UpdateNumber == 4294967294)
				UpdateNumber = 0;
			else
				UpdateNumber = previous.UpdateNumber + 1;
		}
		
		if(IsPaused != previous.IsPaused) // Note that this is only actually paused in singleplayer
			dEventInfo.PauseChange = true;
		if((IsMultiplayer != previous.IsMultiplayer || dServerInfo.ServerLogin != previous.dServerInfo.ServerLogin)) // This is "" when leaving server
			dEventInfo.ServerChange = true;
		if(dMapInfo.EdChallengeId != previous.dMapInfo.EdChallengeId) // This is "" when changing map or leaving server
			dEventInfo.MapChange = true;
		if(dServerInfo.CurGameModeStr != previous.dServerInfo.CurGameModeStr) // This is "" when leaving server
			dEventInfo.GameModeChange = true;
			
		// We've passed more cps than previously and we're driving (to eliminate the weird time when joining a server where it changes NumCPs to 1 and you're not yet driving)
		if(dMLData.NumCPs > previous.dMLData.NumCPs && dMLData.NumCPs > 0 && PlayerState == EPlayerState::EPlayerState_Driving) 
		{
			dEventInfo.CheckpointChange = true; // Set the event
			dPlayerInfo.NumberOfCheckpointsPassed = previous.dPlayerInfo.NumberOfCheckpointsPassed + 1; // Increment the number of cps passed
			AddCheckpointTime(false); // Add checkpoint time, but not a finish time
		}
		else if(dPlayerInfo.LatestCheckpointLandmarkIndex != dMapInfo.StartCPNumber) // Else copy from previous state
		{
			dPlayerInfo.NumberOfCheckpointsPassed = previous.dPlayerInfo.NumberOfCheckpointsPassed;
			dPlayerInfo.RaceWaypointTimes = previous.dPlayerInfo.RaceWaypointTimes;
			dMLData.NumCPs = previous.dMLData.NumCPs;
		}
		
		// If we're counting down but were driving previously, meaning we either finished or ended our run prematurely
		if(PlayerState == EPlayerState::EPlayerState_Countdown && previous.PlayerState == EPlayerState::EPlayerState_Driving && dPlayerInfo.LatestCheckpointLandmarkIndex == dMapInfo.StartCPNumber)
		{
			dPlayerInfo.CurrentRaceTime = previous.dPlayerInfo.CurrentRaceTime; // Take the previous CurrentRaceTime because we're actually already counting down
			PlayerState = EPlayerState::EPlayerState_EndRace; // Manually adjust to end race to get the event later in this function
		}
		
		// Finish also counts as NumCPs but have been excluded from NumberOfCheckpoints
		if(dMLData.NumCPs  > dMapInfo.NumberOfCheckpoints)
		{
			PlayerState = EPlayerState::EPlayerState_Finished;
			dPlayerInfo.EndTime = previous.dPlayerInfo.EndTime;
		}
		
		if(PlayerState != previous.PlayerState)
		{
			dEventInfo.PlayerStateChange = true;
			
			if(PlayerState == EPlayerState::EPlayerState_Finished)
			{
				AddCheckpointTime(true);
				dEventInfo.FinishRun = true;
				dEventInfo.EndRun = true;
			}
			else if(PlayerState == EPlayerState::EPlayerState_EndRace)
				dEventInfo.EndRun = true;
		}
		
		// Check for changes in any handicaps
		if(	   dPlayerInfo.HandicapNoGasDuration 		< previous.dPlayerInfo.HandicapNoGasDuration
			|| dPlayerInfo.HandicapForceGasDuration 	< previous.dPlayerInfo.HandicapForceGasDuration  
			|| dPlayerInfo.HandicapNoBrakesDuration 	< previous.dPlayerInfo.HandicapNoBrakesDuration 
			|| dPlayerInfo.HandicapNoSteeringDuration 	< previous.dPlayerInfo.HandicapNoSteeringDuration 
			|| dPlayerInfo.HandicapNoGripDuration 		< previous.dPlayerInfo.HandicapNoGripDuration
			||(dPlayerInfo.HandicapNoGasDuration 		> 0 && previous.dPlayerInfo.HandicapNoGasDuration == 0)
			||(dPlayerInfo.HandicapForceGasDuration 	> 0 && previous.dPlayerInfo.HandicapForceGasDuration == 0)  
			||(dPlayerInfo.HandicapNoBrakesDuration 	> 0 && previous.dPlayerInfo.HandicapNoBrakesDuration == 0) 
			||(dPlayerInfo.HandicapNoSteeringDuration 	> 0 && previous.dPlayerInfo.HandicapNoSteeringDuration == 0) 
			||(dPlayerInfo.HandicapNoGripDuration 		> 0 && previous.dPlayerInfo.HandicapNoGripDuration == 0))
			dEventInfo.HandicapChange = true;
	}
	
	void AddCheckpointTime(bool bFinishTime = false)
	{
		int RaceTime =  dPlayerInfo.CurrentRaceTime; // Use the CurrentRaceTime by default
		
		if(dMLData.NumCPs > 0) // But use the ML CP time if possible since it's more accurate
			RaceTime = dMLData.PlayerLastCheckpointTime;
		
		dPlayerInfo.RaceWaypointTimes.InsertLast(RaceTime);
		
		if(bFinishTime && dPlayerInfo.EndTime == 0) // Set the endtime to the CurrentRaceTime just in case
			dPlayerInfo.EndTime = RaceTime;
	}
	
	// This is only called when there is no reference data from the previous sTMData state
	void InitialData()
	{
		if(IsPaused)
			dEventInfo.PauseChange = true;
			
		if(IsMultiplayer)
			dEventInfo.ServerChange = true;
			
		if(dMapInfo.EdChallengeId != "")
			dEventInfo.MapChange = true;
		
		if(PlayerState != EPlayerState::EPlayerState_Menus)
		{
			dEventInfo.PlayerStateChange = true;
			dEventInfo.GameModeChange = true;
			
			if(PlayerState == EPlayerState::EPlayerState_EndRace)
			{
				dEventInfo.EndRun = true;
			}
			else if(PlayerState == EPlayerState::EPlayerState_Finished)
			{
				dEventInfo.EndRun = true;
				dEventInfo.FinishRun = true;
			}
			else if(PlayerState == EPlayerState::EPlayerState_Driving)
			{
				if(dPlayerInfo.HandicapNoGasDuration > 0 || dPlayerInfo.HandicapForceGasDuration > 0 || dPlayerInfo.HandicapNoBrakesDuration > 0 || dPlayerInfo.HandicapNoSteeringDuration > 0 || dPlayerInfo.HandicapNoGripDuration > 0)
					dEventInfo.HandicapChange = true;
					
				if(dPlayerInfo.LatestCheckpointLandmarkIndex < dMapInfo.NumberOfCheckpoints)
					dEventInfo.CheckpointChange = true;
			}
		}
	}
	
	void Update(sTMData@ previous) // TODO: use previous to determine when to update things that don't need to update very tick, e.g. mapinfo, serverinfo
	{
		// CGamePlaygroundScript@ PlaygroundScript; // app.PlaygroundScript; // Null if online
		// CGameCtnChallengeInfo@ MapInfo; // RootMap.MapInfo; // null pointer access while loading map
		
		// These are all variables we'll need for updating
		CGameCtnApp@ app;
		CSmArenaClient@ CurrentPlayground; // Null if in menu
		CGameCtnNetwork@ Network;
		CTrackManiaNetworkServerInfo@ ServerInfo;
		CGamePlaygroundClientScriptAPI@ PlaygroundClientScriptAPI;
		CGameCtnChallenge@ RootMap;
		CSmPlayer@ Player;
		CSmScriptPlayer@ ScriptAPI;
		
		// These are required to retrieve data from the manialink we're using
		CGamePlaygroundUIConfig@ clientUI;
		CGameManiaAppPlayground@ UIMgr;
		CGameUILayer@ UI_Data_Layer = null;

		
		// Get references to all the variables we'll need and ensure we don't get any null pointer access errors
		@app = GetApp();
		if(app is null || app.CurrentPlayground is null)
			return;
		
		@CurrentPlayground = cast<CSmArenaClient>(app.CurrentPlayground);
		if(CurrentPlayground is null) // We're in menu
			PlayerState = EPlayerState::EPlayerState_Menus;
		
		@Network = app.Network;
		if(Network is null)
			return;
		@ServerInfo = cast<CTrackManiaNetworkServerInfo>(Network.ServerInfo);
		@PlaygroundClientScriptAPI = Network.PlaygroundClientScriptAPI;
		@RootMap = app.RootMap;
		if(PlaygroundClientScriptAPI is null || ServerInfo is null || RootMap is null)
			return;
		
		
		// Set the values of this class and update the several *Info variables
		IsSpectator = PlaygroundClientScriptAPI.IsSpectator;
		IsPaused = PlaygroundClientScriptAPI.IsInGameMenuDisplayed;
		IsMultiplayer = app.PlaygroundScript is null; // 
		dGameInfo.Update(CurrentPlayground, PlaygroundClientScriptAPI, previous);
		dServerInfo.Update(CurrentPlayground, ServerInfo);
		dMapInfo.Update(RootMap, CurrentPlayground);
		
		// We need these to find the local player
		if(CurrentPlayground.GameTerminals.get_Length() < 1 || CurrentPlayground.GameTerminals[0].ControlledPlayer is null)
			return;

		@Player = cast<CSmPlayer>(CurrentPlayground.GameTerminals[0].ControlledPlayer);		
		@ScriptAPI = Player.ScriptAPI;		
		if(Player is null || ScriptAPI is null)
			return;
		
		// Update playerinfo and the state (other than Menu state)
		dPlayerInfo.Update(ScriptAPI, Player, dGameInfo.GameTime);
		PlayerState = GetPlayerState(ScriptAPI, previous);
		
		// All this is needed to get the UI labels to retrieve the values we set in the manialink
		@UIMgr = cast<CGameManiaAppPlayground>(Network.ClientManiaAppPlayground); //This is ClientSide ManiaApp 
		if(UIMgr is null)
			return;
		
		@clientUI = cast<CGamePlaygroundUIConfig>(UIMgr.ClientUI); //We access ClientSide UI class
		if(clientUI is null)
			return;
			
		@UI_Data_Layer = GetLayer(GetDataML(), "AR_Data", UIMgr, clientUI);
		auto ML_localpage = cast<CGameManialinkPage>(UI_Data_Layer.LocalPage);//We load Manialink page to function like "GetFirstChild"
		if(ML_localpage is null)
			return;

		auto LocalPlayer_Label = cast<CGameManialinkLabel>(ML_localpage.GetFirstChild("LocalPlayer"));
		auto AllPlayers_Label = cast<CGameManialinkLabel>(ML_localpage.GetFirstChild("AllPlayers"));
		auto NumCPs_Label = cast<CGameManialinkLabel>(ML_localpage.GetFirstChild("NumCPs"));
		auto PlayerLastCheckpointTime_Label = cast<CGameManialinkLabel>(ML_localpage.GetFirstChild("PlayerLastCheckpointTime"));
		
		if(LocalPlayer_Label is null || AllPlayers_Label is null || NumCPs_Label is null || PlayerLastCheckpointTime_Label is null)
			return;
		
		dMLData.PlayerData = LocalPlayer_Label.Value;
		dMLData.AllPlayerData = AllPlayers_Label.Value;
		dMLData.NumCPs = Text::ParseInt(NumCPs_Label.Value);
		dMLData.PlayerLastCheckpointTime = Text::ParseInt(PlayerLastCheckpointTime_Label.Value);
	}
	
	string Serialize()
	{
		auto obj = Json::Object();
		obj["PlayerState"] = PlayerState; //EPlayerStateToString(PlayerState);
		obj["IsPaused"] = IsPaused;
		obj["IsMultiplayer"] = IsMultiplayer;
		obj["IsSpectator"] = IsSpectator;
		obj["UpdateNumber"] = UpdateNumber;
		obj["dGameInfo"] = dGameInfo.Serialize();
		obj["dMapInfo"] = dMapInfo.Serialize();
		obj["dPlayerInfo"] = dPlayerInfo.Serialize();
		obj["dEventInfo"] = dEventInfo.Serialize();
		obj["dServerInfo"] = dServerInfo.Serialize();
		
		return Json::Write(obj);	
	}
	
	void WriteToFile(string FileName = "TMData")
	{
		string File_To_Load = IO::FromDataFolder(scriptFolder + FileName + ".json");
		IO::File file(File_To_Load);
		file.Open(IO::FileMode::Write);
		string Content = Serialize();
		file.WriteLine(Content);
		file.WriteLine(Json::Write(dMLData.Serialize()));
		file.Close();
	}
		
	void WriteMap()
	{
	}
	
}

class sGameInfo
{
	// Code determined values
	int Period;
	
	// Game determined values
	int GameTime; // app.Network.PlaygroundClientScriptAPI
	//int NumberOfGhosts; // app.CurrentPlayground.ReplayRecord.Ghosts
	//int[] GhostTimes; // app.CurrentPlayground.ReplayRecord.Ghosts
	
	void Update(CGamePlayground@ CurrentPlayground, CGamePlaygroundClientScriptAPI@ PlaygroundClientScriptAPI, sTMData@ previous)
	{
		GameTime = PlaygroundClientScriptAPI.GameTime;
		
		if(previous !is null)
			Period = GameTime - previous.dGameInfo.GameTime;
	}
	
	Json::Value Serialize()
	{
		auto obj = Json::Object();
		obj["Period"] = "" + Period;
		obj["GameTime"] = "" + GameTime;
		
		return obj;
	}
}

class sServerInfo
{
	int PlayerCount; // CurrentPlayground.Players
	sOnlinePlayerInfo[] OnlinePlayers; // CurrentPlayground.Players
	string ServerName; // CurrentPlayground
	string ServerLogin = ""; // CurrentPlayground
	string CurGameModeStr; // ServerInfo
	
	void Update(CGamePlayground@ CurrentPlayground, CTrackManiaNetworkServerInfo@ ServerInfo)
	{
		ServerLogin = ServerInfo.ServerLogin;
		ServerName = ServerInfo.ServerName;
		
		CurGameModeStr = ServerInfo.CurGameModeStr; // You could use this to determine whether it's online or offline or rounds or time-attack or custom
				
		PlayerCount = CurrentPlayground.Players.get_Length();
		
		if(PlayerCount == 0)
			return;
		
		for(int i = 0; i < PlayerCount; i++)
		{
			if(CurrentPlayground.Players[i] !is null)
				OnlinePlayers.InsertLast(sOnlinePlayerInfo(CurrentPlayground.Players[i]));
		}
	}
	
	Json::Value Serialize()
	{
		auto obj = Json::Object();
		obj["PlayerCount"] = PlayerCount;
		obj["ServerName"] = ServerName;
		obj["ServerLogin"] = ServerLogin;
		obj["CurGameModeStr"] = CurGameModeStr;
		
		auto arr = Json::Array();
		for(uint i = 0; i < OnlinePlayers.get_Length(); i++)
		{
			arr.Add(OnlinePlayers[i].Serialize());
		}
		obj["OnlinePlayers"] = arr;
		
		return obj;
	}
}

class sOnlinePlayerInfo
{
	string Login; // CSmPlayer.User
	string Name; // CSmPlayer.User
	
	sOnlinePlayerInfo()
	{
	}
	
	sOnlinePlayerInfo(CGamePlayer@ Player)
	{
		if(Player is null)
			return;
			
		CSmPlayer@ SmPlayer = cast<CSmPlayer>(Player);
		if(SmPlayer is null)
			return;
		
		CGamePlayerInfo@ PlayerInfo = SmPlayer.User;
		if(PlayerInfo is null)
			return;
		
		Login = PlayerInfo.Login;
		Name = PlayerInfo.Name;
	}
	
	Json::Value Serialize()
	{
		auto obj = Json::Object();
		obj["Login"] = Login;
		obj["Name"] = Name;
		
		return obj;
	}
}

class sMapInfo
{
	string EdChallengeId = ""; // RootMap
	string MapName; // RootMap
	string AuthorLogin; // RootMap
	string AuthorNickName; // RootMap
	string MapType; // RootMap
	string MapStyle; // RootMap
	
	uint TMObjective_NbLaps; // RootMap
	bool TMObjective_IsLapRace; // RootMap
	uint TMObjective_AuthorTime;  // RootMap
	uint TMObjective_GoldTime;  // RootMap
	uint TMObjective_SilverTime; // RootMap
	uint TMObjective_BronzeTime; // RootMap
	
	int NumberOfCheckpoints; // CurrentPlayground.Arena.MapLandmarks.Tag = "Checkpoint", "Goal" = Finish, "Spawn"=  Start
	int StartCPNumber;
	
	// BlockInfo[]@ PlayerSpawns;
	// BlockInfo[]@ MapWaypoints;
	
	// BlockInfo[]@ Blocks;
	
	void Update(CGameCtnChallenge@ RootMap, CSmArenaClient@ CurrentPlayground)
	{
		EdChallengeId = RootMap.EdChallengeId;
		AuthorLogin = RootMap.AuthorLogin;
		AuthorNickName = RootMap.AuthorNickName;
		MapType = RootMap.MapType;
		MapStyle = RootMap.MapStyle;
		MapName = RootMap.MapInfo.Name;
		
		TMObjective_NbLaps = RootMap.TMObjective_NbLaps;
		TMObjective_IsLapRace = RootMap.TMObjective_IsLapRace;
		TMObjective_AuthorTime = RootMap.TMObjective_AuthorTime;
		TMObjective_GoldTime = RootMap.TMObjective_GoldTime;
		TMObjective_SilverTime = RootMap.TMObjective_SilverTime;
		TMObjective_BronzeTime = RootMap.TMObjective_BronzeTime;
		
		if(CurrentPlayground is null || CurrentPlayground.Arena is null || CurrentPlayground.Arena.MapLandmarks.get_Length() < 1)
			return;
		
		uint numLandmarks = CurrentPlayground.Arena.MapLandmarks.get_Length();
		
		for(uint i = 0; i < numLandmarks; i++)
		{
			if(CurrentPlayground.Arena.MapLandmarks[i] !is null)
			{
				if(CurrentPlayground.Arena.MapLandmarks[i].Tag == "Checkpoint")
					NumberOfCheckpoints++;
				else if(CurrentPlayground.Arena.MapLandmarks[i].Tag == "Spawn")
					StartCPNumber = i;
			}
		}
		
	}
	
	Json::Value Serialize()
	{
		auto obj = Json::Object();
		obj["EdChallengeId"] = EdChallengeId;
		obj["MapName"] = MapName;
		obj["AuthorLogin"] = AuthorLogin;
		obj["AuthorNickName"] = AuthorNickName;
		obj["MapType"] = MapType;
		obj["MapStyle"] = MapStyle;
		obj["TMObjective_NbLaps"] = TMObjective_NbLaps;
		obj["TMObjective_IsLapRace"] = TMObjective_IsLapRace;
		obj["TMObjective_AuthorTime"] = TMObjective_AuthorTime;
		obj["TMObjective_GoldTime"] = TMObjective_GoldTime;
		obj["TMObjective_SilverTime"] = TMObjective_SilverTime;
		obj["TMObjective_BronzeTime"] = TMObjective_BronzeTime;
		obj["NumberOfCheckpoints"] = NumberOfCheckpoints;
		obj["StartCPNumber"] = StartCPNumber;
		
		return obj;
	}
}


class sPlayerInfo
{
	// Values determined by code
	int EndTime; // End time of the current run, see also IsFinish to see whether the time is a result of a finish or a reset
	uint[] RaceWaypointTimes; // Also available in string format from sMLData
	uint[] LapWaypointTimes; // TODO: find a way to implement this
	uint NumberOfCheckpointsPassed; // This is actually the same as the length of RaceWaypointTimes but whatever...
	int CurrentRaceTime; // CSmPlayer.ScriptAPI <-- doesn't work online so we calculate based on GameTime - StartTime

	// Values determined by TM (online)
	int StartTime; // CSmPlayer.ScriptAPI; in GameTime
	uint CurrentLapNumber; // CSmPlayer.ScriptAPI TODO: check if this works
	int LapStartTime; // CSmPlayer.ScriptAPI TODO: check if this works
	vec3 Position; // CSmPlayer.ScriptAPI
	float AimYaw; // CSmPlayer.ScriptAPI
	float AimPitch; // CSmPlayer.ScriptAPI
	vec3 AimDirection; // CSmPlayer.ScriptAPI
	vec3 Velocity; // CSmPlayer.ScriptAPI
	float Speed; // CSmPlayer.ScriptAPI
	string Login; // CSmPlayer.ScriptAPI
	string Name; // CSmPlayer.ScriptAPI
	int LatestCheckpointLandmarkIndex; // CSmPlayer; starts at the maximum number of checkpoints + finish + start, after first cp goes to 0 and up from there
	uint TrustClientSimu_ServerOverrideCount; // CSmPlayer; increases when the player ends the run
	
	// The following only work in singleplayer
	float Upwardness; // CSmPlayer.ScriptAPI
	float Distance; // CSmPlayer.ScriptAPI
	uint DisplaySpeed; // CSmPlayer.ScriptAPI
	float InputSteer; // CSmPlayer.ScriptAPI
	float InputGasPedal; // CSmPlayer.ScriptAPI
	bool InputIsBraking; // CSmPlayer.ScriptAPI
	float EngineRpm; // CSmPlayer.ScriptAPI
	int EngineCurGear; // CSmPlayer.ScriptAPI
	float EngineTurboRatio; // CSmPlayer.ScriptAPI
	uint WheelsContactCount; // CSmPlayer.ScriptAPI
	uint WheelsSkiddingCount; // CSmPlayer.ScriptAPI
	uint FlyingDuration; // CSmPlayer.ScriptAPI
	uint SkiddingDuration; // CSmPlayer.ScriptAPI
	float SkiddingDistance; // CSmPlayer.ScriptAPI
	float FlyingDistance; // CSmPlayer.ScriptAPI
	uint HandicapNoGasDuration; // CSmPlayer.ScriptAPI
	uint HandicapForceGasDuration; // CSmPlayer.ScriptAPI
	uint HandicapNoBrakesDuration; // CSmPlayer.ScriptAPI
	uint HandicapNoSteeringDuration; // CSmPlayer.ScriptAPI
	uint HandicapNoGripDuration; // CSmPlayer.ScriptAPI
	
	
	void Update(CSmScriptPlayer@ ScriptAPI, CSmPlayer@ SmPlayer, int GameTime)
	{		
		StartTime = ScriptAPI.StartTime;
		CurrentRaceTime = GameTime - ScriptAPI.StartTime;
		CurrentLapNumber = ScriptAPI.CurrentLapNumber;
		LapStartTime = ScriptAPI.LapStartTime;
		Position = ScriptAPI.Position;
		AimYaw = ScriptAPI.AimYaw;
		AimPitch = ScriptAPI.AimPitch;
		AimDirection = ScriptAPI.AimDirection;
		Velocity = ScriptAPI.Velocity;
		Speed = ScriptAPI.Speed;
		Upwardness = ScriptAPI.Upwardness;
		Distance = ScriptAPI.Distance;
		//DisplaySpeed = ScriptAPI.DisplaySpeed;
		DisplaySpeed = Velocity.Length() * 3.6f;
		InputSteer = ScriptAPI.InputSteer;
		InputGasPedal = ScriptAPI.InputGasPedal;
		InputIsBraking = ScriptAPI.InputIsBraking;
		EngineRpm = ScriptAPI.EngineRpm;
		EngineCurGear = ScriptAPI.EngineCurGear;
		EngineTurboRatio = ScriptAPI.EngineTurboRatio;
		WheelsContactCount = ScriptAPI.WheelsContactCount;
		WheelsSkiddingCount = ScriptAPI.WheelsSkiddingCount;
		FlyingDuration = ScriptAPI.FlyingDuration;
		SkiddingDuration = ScriptAPI.SkiddingDuration;
		SkiddingDistance = ScriptAPI.SkiddingDistance;
		FlyingDistance = ScriptAPI.FlyingDistance;
		HandicapNoGasDuration = ScriptAPI.HandicapNoGasDuration;
		HandicapForceGasDuration = ScriptAPI.HandicapForceGasDuration;
		HandicapNoBrakesDuration = ScriptAPI.HandicapNoBrakesDuration;
		HandicapNoSteeringDuration = ScriptAPI.HandicapNoSteeringDuration;
		HandicapNoGripDuration = ScriptAPI.HandicapNoGripDuration;
		Login = ScriptAPI.Login;
		Name = ScriptAPI.Name;
		LatestCheckpointLandmarkIndex = SmPlayer.CurrentLaunchedRespawnLandmarkIndex;
		TrustClientSimu_ServerOverrideCount = SmPlayer.TrustClientSimu_ServerOverrideCount;
	}
	
	Json::Value Serialize()
	{
		auto obj = Json::Object();
		obj["StartTime"] = "" + StartTime;
		obj["CurrentRaceTime"] = "" + CurrentRaceTime;
		obj["CurrentLapNumber"] = CurrentLapNumber;
		obj["LapStartTime"] = "" + LapStartTime;
		obj["Position"] = SerializeVec3(Position);
		obj["AimYaw"] = AimYaw;
		obj["AimPitch"] = AimPitch;
		obj["AimDirection"] = SerializeVec3(AimDirection);
		obj["Velocity"] = SerializeVec3(Velocity);
		obj["Speed"] = Speed;
		obj["Upwardness"] = Upwardness;
		obj["Distance"] = Distance;
		obj["DisplaySpeed"] = DisplaySpeed;
		obj["InputSteer"] = InputSteer;
		obj["InputGasPedal"] = InputGasPedal;
		obj["InputIsBraking"] = InputIsBraking;
		obj["EngineRpm"] = EngineRpm;
		obj["EngineCurGear"] = EngineCurGear;
		obj["EngineTurboRatio"] = EngineTurboRatio;
		obj["WheelsContactCount"] = WheelsContactCount;
		obj["WheelsSkiddingCount"] = WheelsSkiddingCount;
		obj["FlyingDuration"] = FlyingDuration;
		obj["SkiddingDuration"] = SkiddingDuration;
		obj["SkiddingDistance"] = SkiddingDistance;
		obj["FlyingDistance"] = FlyingDistance;
		obj["HandicapNoGasDuration"] = HandicapNoGasDuration;
		obj["HandicapForceGasDuration"] = HandicapForceGasDuration;
		obj["HandicapNoBrakesDuration"] = HandicapNoBrakesDuration;
		obj["HandicapNoSteeringDuration"] = HandicapNoSteeringDuration;
		obj["HandicapNoGripDuration"] = HandicapNoGripDuration;
		obj["Login"] = Login;
		obj["Name"] = Name;
		obj["LatestCheckpointLandmarkIndex"] = LatestCheckpointLandmarkIndex;
		obj["TrustClientSimu_ServerOverrideCount"] = TrustClientSimu_ServerOverrideCount;
		obj["NumberOfCheckpointsPassed"] = NumberOfCheckpointsPassed;
		obj["EndTime"] = "" + EndTime;
		
		if(RaceWaypointTimes.get_Length() > 0)
		{
			auto arr = Json::Array();
			for(uint i = 0; i < RaceWaypointTimes.get_Length(); i++)
			{
				arr.Add(RaceWaypointTimes[i]);
			}
			obj["RaceWaypointTimes"] = arr;
		}
		
		
		return obj;
	}
}

