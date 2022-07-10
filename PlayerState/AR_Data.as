namespace PlayerState
{


	shared string EPlayerStateToString(EPlayerState State)
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
		else if(State == EPlayerState::EPlayerState_InEditor)
			return "EPlayerState_InEditor";
		return "";
	}

	shared enum EPlayerState  // The below might not entirely be correct anymore
	{
		EPlayerState_Menus = 0, // app.CurrentPlayground is null
		EPlayerState_Countdown, // [sPlayerInfo.CurrentRaceTime] < 0.0f && CSmPlayer.ScriptAPI.Post != EPost::CarDriver
		EPlayerState_Driving, // [sPlayerInfo.CurrentRaceTime] > 0.0f && CSmPlayer.ScriptAPI.Post == EPost::CarDriver
		EPlayerState_EndRace, // [sPlayerInfo.CurrentRaceTime] < 0.0f && Previous PlayerState was EPlayerState_Driving ~ unsure about both of these
		EPlayerState_Finished, // [sPlayerInfo.LatestCheckpointLandmarkIndex]  == [sMapInfo.NumberOfCheckpoints]      (CurrentPlayground.ReplayRecord.Ghosts > previous amount of ghosts)
		EPlayerState_Spectating, // [IsSpectator]
		EPlayerState_InEditor, // [app.Editor] !is null
	}
	
	shared enum ERespawnType
	{
		ERespawnType_None = 0,
		ERespawnType_Running,
		ERespawnType_Standing,
	}

	shared class sEventInfo
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
		bool LapChange; // TODO: add this to Json
		bool bRespawned; // True when the player has just respawned a checkpoint
		bool bRespawnChange; // True when the player has just started or ended the respawn
	}

	shared class sMLData
	{
		// Login,@,StartTime,@,CurrentRaceTime,@,RaceWaypointTimes.Count,@,CP0,CP1,CP2...
		string PlayerData; // NumCPs and all checkpoint times, separated by ",@," and "," respectively
		string AllPlayerData; // Contains Login, the above, and CurrentRaceTime, players are separated by ",$,$,"
		int NumCPs; // Number of checkpoints the player has passed through, somehow changes to 1 when joining a server and not yet started playing, not serialized
		int PlayerLastCheckpointTime; // 0 or the most recent checkpoint time, not serialized
		int StartTime;
		int CurrentRaceTime;
	}

	shared class sTMData
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

		CGameUILayer@ UI_Data_Layer; // DO NOT ACCESS DIRECTLY

		wstring Data_ML = """<label pos="145 -81" z-index="0" size="1 1" text="1" style="TextValueSmallSm" valign="center2" halign="center" id="LocalPlayer" opacity="0"/>
							<label pos="145 -81" z-index="0" size="1 1" text="1" style="TextValueSmallSm" valign="center2" halign="center" id="NumCPs" opacity="0"/>
							<label pos="145 -81" z-index="0" size="1 1" text="1" style="TextValueSmallSm" valign="center2" halign="center" id="PlayerLastCheckpointTime" opacity="0"/>
							<label pos="50 -61" z-index="0" size="20 16" text="1" style="TextValueSmallSm" valign="center2" halign="center" id="AllPlayers" opacity="0"/>
							<script><!-- #Include "TextLib" as TL
							declare CMlLabel L1 <=> (Page.GetFirstChild("LocalPlayer") as CMlLabel);
							declare CMlLabel L2 <=> (Page.GetFirstChild("NumCPs") as CMlLabel);
							declare CMlLabel L3 <=> (Page.GetFirstChild("PlayerLastCheckpointTime") as CMlLabel);
							declare CMlLabel A1 <=> (Page.GetFirstChild("AllPlayers") as CMlLabel);

							while(True)
							{
								yield;
								declare Text FullTime = "";
								declare Integer NumCPs = 0;
								declare Text FullText = "";
								declare Text LastTime = "0";
								declare Text CurrentRaceTime = "-10000";
								declare Text FullPlayerText = "";

								foreach(Player in Players)
								{

									if(Player.Login == LocalUser.Login)
									{
										NumCPs = Player.RaceWaypointTimes.count;
										if(Player.RaceWaypointTimes.count > 0)
										{
											foreach (Time in Player.RaceWaypointTimes)
											{
												FullTime = FullTime ^ Time ^ ",";
												LastTime = TL::ToText(Time);
											}
										}
									}

									declare Text PlayerText = Player.Login ^ ",@," ^ TL::ToText(Player.StartTime) ^ ",@," ^ TL::ToText(Player.CurrentRaceTime) ^ ",@," ^ Player.RaceWaypointTimes.count ^ ",@,";
									declare Text CPText = "";

									if(Player.Login == LocalUser.Login)
									{
										FullPlayerText = PlayerText;
									}

									foreach (Time in Player.RaceWaypointTimes)
									{
										CPText = CPText ^ Time ^ ",";
									}

									PlayerText = PlayerText ^ CPText;
									FullText = FullText ^ PlayerText ^ ",$,$,";
								}
								L1.SetText(FullPlayerText ^ FullTime);
								L2.SetText(TL::ToText(NumCPs));
								L3.SetText(LastTime);
								A1.SetText(FullText);
							}
							--></script>""";

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
			if(ScriptAPI.Post == CSmScriptPlayer::EPost::CarDriver && previous !is null && previous.PlayerState == EPlayerState::EPlayerState_Countdown) // Only go to driving if you were counting down previously
				return EPlayerState::EPlayerState_Driving;

			if(previous !is null) // If in doubt, copy the prior version
				return previous.PlayerState;

			return EPlayerState::EPlayerState_Menus; // Not sure if this ever happens, but it only could happen on the first iteration or when no previous data is supplied (which you should always do if possible)
		}


		// Returns the layer in the player's UI or creates it if there is none (i.e. after leaving the menu), returns null if the LocalPage of the UILayer is null
		CGameUILayer@ GetLayer(wstring manialink, const string &in id, CGameManiaAppPlayground@ UIMgr, CGamePlaygroundUIConfig@ clientUI)
		{
			for(uint i = 0; i < UIMgr.UILayers.Length; ++i) //This is used to check if we haven't already a layer with the same id, to avoid doubles
			{
				auto layer = cast<CGameUILayer>(UIMgr.UILayers[i]);
				if(layer.LocalPage is null)
					print("The UI Layer does not have a valid LocalPage");
				else if(layer.AttachId == id)
					return layer;
			}

			auto injected_layer = UIMgr.UILayerCreate(); //This create a ML Layer in client UI
			injected_layer.AttachId = id; //We'll use AttachId as a reference to get organized in which UI is what
			injected_layer.ManialinkPage = manialink; //This is where the manialink code is

			return injected_layer;// The function return the layer pointer to easily modify stuff in it
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
				if(previous.UpdateNumber == 0xFFFFFFFE)
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

			if(!dEventInfo.MapChange)
			{
				dMapInfo.bIsMultiLap = previous.dMapInfo.bIsMultiLap;
			}
			else
			{
				// Consider resetting values here if map is set to ""
			}

			// We've passed more cps than previously and we're driving (to eliminate the weird time when joining a server where it changes NumCPs to 1 and you're not yet driving)
			if(dMLData.NumCPs > previous.dMLData.NumCPs && dMLData.NumCPs > 0 && PlayerState == EPlayerState::EPlayerState_Driving)
			{
				dEventInfo.CheckpointChange = true; // Set the event
				uint CPTime = AddCheckpointTime(false); // Add checkpoint time, but not a finish time
				dPlayerInfo.LatestCPTime = CPTime;
			}

			dPlayerInfo.RaceWaypointTimes = previous.dPlayerInfo.RaceWaypointTimes;
			dPlayerInfo.CurrentLapNumber = previous.dPlayerInfo.CurrentLapNumber;
			dPlayerInfo.NumberOfCheckpointsPassed = dMLData.NumCPs - (dMapInfo.NumberOfCheckpoints + 1) * dPlayerInfo.CurrentLapNumber;
			dPlayerInfo.LapStartTime = previous.dPlayerInfo.LapStartTime;

			// If we're counting down but were driving previously, meaning we either finished or ended our run prematurely
			if(PlayerState == EPlayerState::EPlayerState_Countdown && previous.PlayerState == EPlayerState::EPlayerState_Driving)// && dPlayerInfo.LatestCheckpointLandmarkIndex == dMapInfo.StartCPNumber)
			{
				dPlayerInfo.CurrentRaceTime = previous.dPlayerInfo.CurrentRaceTime; // Take the previous CurrentRaceTime because we're actually already counting down
				PlayerState = EPlayerState::EPlayerState_EndRace; // Manually adjust to end race to get the event later in this function
			}

			int LapCPs = dMLData.NumCPs - dPlayerInfo.CurrentLapNumber * dMapInfo.NumberOfCheckpoints;

			// Finish also counts as NumCPs but have been excluded from NumberOfCheckpoints
			if(LapCPs  > dMapInfo.NumberOfCheckpoints && previous.PlayerState != EPlayerState::EPlayerState_Finished && !IsSpectator && PlayerState == EPlayerState_Driving)
			{
				if(dMapInfo.IsFinish(dPlayerInfo.LatestCheckpointLandmarkIndex))
				{
					if(dMapInfo.IsMultiLap(dPlayerInfo.LatestCheckpointLandmarkIndex))
					{
						if(dPlayerInfo.CurrentLapNumber < dMapInfo.TMObjective_NbLaps - 1)
						{
							dPlayerInfo.CurrentLapNumber++;
							dEventInfo.LapChange = true;
							dPlayerInfo.NumberOfCheckpointsPassed = 0;
							dPlayerInfo.LapStartTime = dMLData.PlayerLastCheckpointTime;
						}
						else
						{
							PlayerState = EPlayerState::EPlayerState_Finished;
							dPlayerInfo.EndTime = previous.dPlayerInfo.EndTime;
						}
					}
					else
					{
						PlayerState = EPlayerState::EPlayerState_Finished;
						dPlayerInfo.EndTime = previous.dPlayerInfo.EndTime;
					}
				}
			}

			// Handle playerstate change events
			if(PlayerState != previous.PlayerState)
			{
				dEventInfo.PlayerStateChange = true;

				if(PlayerState == EPlayerState::EPlayerState_Finished)
					EndRun(true);
				else if(PlayerState == EPlayerState::EPlayerState_EndRace)
					EndRun(false);
				else if(PlayerState == EPlayerState::EPlayerState_Driving)
					StartRun();
			}

			// Handle respawn events
			dEventInfo.bRespawned = previous.dEventInfo.bRespawned;
			dEventInfo.bRespawnChange = false;
			dPlayerInfo.RespawnTime = previous.dPlayerInfo.RespawnTime;
			dPlayerInfo.RespawnType = previous.dPlayerInfo.RespawnType;
			if(PlayerState == EPlayerState::EPlayerState_Driving)
			{
				if(dPlayerInfo.NbRespawnsRequested > previous.dPlayerInfo.NbRespawnsRequested) // We've just respawned
				{
					if(dPlayerInfo.RespawnType == ERespawnType_None) // initial respawn, so running
					{
						dPlayerInfo.RespawnType = ERespawnType_Running;
						dPlayerInfo.RespawnTime = dPlayerInfo.CurrentRaceTime;
						dEventInfo.bRespawned = true;
						dEventInfo.bRespawnChange = true;
					}
					else if(dPlayerInfo.RespawnType == ERespawnType_Running) // secondary respawn, means we're standing now
					{
						dPlayerInfo.RespawnType = ERespawnType_Standing;
						dPlayerInfo.RespawnTime = dPlayerInfo.CurrentRaceTime;
						dEventInfo.bRespawned = true;
						dEventInfo.bRespawnChange = true;
					}
					else if(dPlayerInfo.RespawnType == ERespawnType_Standing) // we're already standing so we'll just ignore this
					{
					}
				}
				else if(dPlayerInfo.RespawnTime != 0) // We're still respawning
				{
					if(dPlayerInfo.Speed != previous.dPlayerInfo.Speed && !previous.dEventInfo.bRespawnChange) // This should mean our respawn ended right?
					{
						dPlayerInfo.RespawnType = ERespawnType_None;
						dPlayerInfo.RespawnTime = 0;
						dEventInfo.bRespawned = false;
						dEventInfo.bRespawnChange = true;
					}
				}
			}
			else // We're not driving so we can't possibly have respawned
			{
				dEventInfo.bRespawned = false;
				dEventInfo.bRespawnChange = false;
				dPlayerInfo.RespawnTime = 0;
				dPlayerInfo.RespawnType = ERespawnType_None;
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

		void StartRun()
		{
			dPlayerInfo.NumberOfCheckpointsPassed = 0;
			dPlayerInfo.CurrentLapNumber = 0;
			dPlayerInfo.LapStartTime = 0;
			if(dMapInfo.bIsMultiLap)
			{
				dEventInfo.LapChange = true;
			}
		}

		void EndRun(bool bFinished = false)
		{
			dEventInfo.EndRun = true;
			if(bFinished)
			{
				AddCheckpointTime(true);
				dEventInfo.FinishRun = true;
			}
		}

		uint AddCheckpointTime(bool bFinishTime = false)
		{
			int RaceTime =  dPlayerInfo.CurrentRaceTime; // Use the CurrentRaceTime by default

			if(dMLData.NumCPs > 0) // But use the ML CP time if possible since it's more accurate
				RaceTime = dMLData.PlayerLastCheckpointTime;

			dPlayerInfo.RaceWaypointTimes.InsertLast(RaceTime);

			if(bFinishTime && dPlayerInfo.EndTime == 0) // Set the endtime to the CurrentRaceTime just in case
				dPlayerInfo.EndTime = RaceTime;

			return RaceTime;
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

			// Get references to all the variables we'll need and ensure we don't get any null pointer access errors
			@app = GetApp();
			if(app is null)
				return;

			if(cast<CGameCtnEditorFree>(app.Editor) !is null)
			{
				PlayerState = EPlayerState::EPlayerState_InEditor;
				return;
			}

			if(app.CurrentPlayground is null)
			{
				PlayerState = EPlayerState::EPlayerState_Menus;
				return;
			}

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
			dMapInfo.Update(RootMap, CurrentPlayground, previous);

			// We need these to find the local player
			if(CurrentPlayground.GameTerminals.get_Length() < 1 || CurrentPlayground.GameTerminals[0].ControlledPlayer is null)
				return;

			@Player = cast<CSmPlayer>(CurrentPlayground.GameTerminals[0].ControlledPlayer);
			@ScriptAPI = cast<CSmScriptPlayer>(Player.ScriptAPI);
			if(Player is null || ScriptAPI is null)
				return;

			// Update playerinfo and the state (other than Menu state)
			dPlayerInfo.Update(ScriptAPI, Player, dGameInfo.GameTime);
			PlayerState = GetPlayerState(ScriptAPI, previous);

			if(PlayerState == EPlayerState::EPlayerState_Menus)
				return;

			// All this is needed to get the UI labels to retrieve the values we set in the manialink
			@UIMgr = cast<CGameManiaAppPlayground>(Network.ClientManiaAppPlayground); //This is ClientSide ManiaApp
			if(UIMgr is null)
				return;

			@clientUI = cast<CGamePlaygroundUIConfig>(UIMgr.ClientUI); //We access ClientSide UI class
			if(clientUI is null)
				return;

			if(previous !is null && previous.UI_Data_Layer !is null && previous.UI_Data_Layer.LocalPage !is null) // Copy this because we will need it again
				@UI_Data_Layer = previous.UI_Data_Layer;

			auto loadMgr = app.LoadProgress;

			if(loadMgr.State == NGameLoadProgress_SMgr::EState::Displayed)
				return;

			if(UI_Data_Layer is null || UI_Data_Layer.LocalPage is null)
				@UI_Data_Layer = this.GetLayer(Data_ML, "AR_Data", UIMgr, clientUI);
			if(UI_Data_Layer is null)
				return;

			auto ML_localpage = cast<CGameManialinkPage>(UI_Data_Layer.LocalPage);//We load Manialink page to function like "GetFirstChild"

			auto LocalPlayer_Label = cast<CGameManialinkLabel>(ML_localpage.GetFirstChild("LocalPlayer"));
			auto AllPlayers_Label = cast<CGameManialinkLabel>(ML_localpage.GetFirstChild("AllPlayers"));
			auto NumCPs_Label = cast<CGameManialinkLabel>(ML_localpage.GetFirstChild("NumCPs"));
			auto PlayerLastCheckpointTime_Label = cast<CGameManialinkLabel>(ML_localpage.GetFirstChild("PlayerLastCheckpointTime"));

			if(LocalPlayer_Label is null || AllPlayers_Label is null || NumCPs_Label is null || PlayerLastCheckpointTime_Label is null)
				return;

			dMLData.PlayerData = LocalPlayer_Label.Value;

			string[] split = dMLData.PlayerData.Split(",@,");
			if(split.Length > 3)
			{
				dMLData.StartTime = Text::ParseInt(split[1]);
				dMLData.CurrentRaceTime = Text::ParseInt(split[2]);
			}
			dMLData.AllPlayerData = AllPlayers_Label.Value;
			dMLData.NumCPs = Text::ParseInt(NumCPs_Label.Value);
			dMLData.PlayerLastCheckpointTime = Text::ParseInt(PlayerLastCheckpointTime_Label.Value);
		}
	}

	shared class sGameInfo
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
	}

	shared class sServerInfo
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
	}

	shared class sOnlinePlayerInfo
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
	}

	shared class sMapInfo
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
		int MultiLapCPNumber = -1;

		bool bIsMultiLap;

		MwFastBuffer<CGameScriptMapLandmark@> MapLandmarks;

		// BlockInfo[]@ PlayerSpawns;
		// BlockInfo[]@ MapWaypoints;

		// BlockInfo[]@ Blocks;

		void Update(CGameCtnChallenge@ RootMap, CSmArenaClient@ CurrentPlayground, sTMData@ previous)
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

			if(previous is null)
				UpdateLandmarks(CurrentPlayground);
			else if(previous.dMapInfo.EdChallengeId == EdChallengeId && previous.dMapInfo.MapLandmarks.get_Length() > 0)
			{
				MapLandmarks = previous.dMapInfo.MapLandmarks;
				NumberOfCheckpoints = previous.dMapInfo.NumberOfCheckpoints;
				StartCPNumber = previous.dMapInfo.StartCPNumber;
			}
			else
				UpdateLandmarks(CurrentPlayground);
		}

		void UpdateLandmarks(CSmArenaClient@ CurrentPlayground)
		{
			uint numLandmarks = CurrentPlayground.Arena.MapLandmarks.get_Length();
			MapLandmarks = CurrentPlayground.Arena.MapLandmarks;
			array<int> links = {};

			for(uint i = 0; i < numLandmarks; i++)
			{
				if(CurrentPlayground.Arena.MapLandmarks[i] !is null)
				{
					if(CurrentPlayground.Arena.MapLandmarks[i].Waypoint !is null)
					{
						if(CurrentPlayground.Arena.MapLandmarks[i].Waypoint.IsMultiLap)
						{
						print(CurrentPlayground.Arena.MapLandmarks[i].Tag);
							bIsMultiLap = true;
						}
					}


					if(CurrentPlayground.Arena.MapLandmarks[i].Tag == "Checkpoint")
						NumberOfCheckpoints++;
					else if(CurrentPlayground.Arena.MapLandmarks[i].Tag == "LinkedCheckpoint")
					{
						if(links.Find(CurrentPlayground.Arena.MapLandmarks[i].Order) < 0)
						{
							NumberOfCheckpoints++;
							links.InsertLast(CurrentPlayground.Arena.MapLandmarks[i].Order);
						}
					}
					else if(CurrentPlayground.Arena.MapLandmarks[i].Tag == "Spawn")
						StartCPNumber = i;
					else if(CurrentPlayground.Arena.MapLandmarks[i].Tag == "StartFinish")
						MultiLapCPNumber = i;
				}
			}
		}

		bool IsMultiLap(int Index)
		{
			if(MapLandmarks.get_Length() < 1)
				return false;

			if(MapLandmarks[Index].Waypoint is null) // Null if start
				return false;

			return MapLandmarks[Index].Waypoint.IsMultiLap;
		}

		bool IsFinish(int Index)
		{
			if(MapLandmarks.get_Length() < 1)
				return false;

			if(MapLandmarks[Index].Waypoint is null) // Null if start
				return false;

			return MapLandmarks[Index].Waypoint.IsFinish;
		}
	}


	shared class sPlayerInfo
	{
		// Values determined by code
		int EndTime; // End time of the current run, see also IsFinish to see whether the time is a result of a finish or a reset
		uint[] RaceWaypointTimes; // Also available in string format from sMLData
		uint[] LapWaypointTimes; // TODO: find a way to implement this
		uint NumberOfCheckpointsPassed;
		uint CurrentLapNumber; // CSmPlayer.ScriptAPI TODO: check if this works
		int CurrentRaceTime; // CSmPlayer.ScriptAPI <-- doesn't work online so we calculate based on GameTime - StartTime
		int LapStartTime; // CSmPlayer.ScriptAPI TODO: check if this works
		uint LatestCPTime;
		ERespawnType RespawnType; // Updates when the player respawns to either standing or running

		// Values determined by TM (online)
		int StartTime; // CSmPlayer.ScriptAPI; in GameTime
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

		uint RespawnTime;
		uint NbRespawnsRequested;

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
			//CurrentLapNumber = ScriptAPI.CurrentLapNumber;
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
			DisplaySpeed = uint(Velocity.Length() * 3.6f);
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
			NbRespawnsRequested = ScriptAPI.Score.NbRespawnsRequested;
		}
	}
} // end of namespace
