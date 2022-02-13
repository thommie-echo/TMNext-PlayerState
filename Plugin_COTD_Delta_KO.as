#name "COTD Delta KO"
#author "AR_Thommie"
#category "Aurora"

#include "AR_Data.as"

[Setting name="XPos"]
int XPos = 50;

[Setting name="YPos"]
int YPos = 350;

[Setting name="Fontsize"]
int fontSize = 18;

[Setting name="Always render"]
bool bAlwaysRender = false;

[Setting name="Log detail level"]
int logDetailLevel = 0;

[Setting name="Enabled"]
bool bEnabled = true;


string currentPlayerID = "";
CustomPlayerData@ currentPlayer;
int currentPlayerCP = -1;
int currentPlayerCPTime = -1;

int firstSafePosition = -1;
int targetCPTime = -1;
int timeDiff = -1;



string NumberFont = "DroidSans.ttf";
Resources::Font@ m_font;

CGameManialinkLabel@ lbl_Players;
CGameManialinkLabel@ lbl_KOs;

vec4 colour_Red = vec4(0, 1, 0, 1);
vec4 colour_Green = vec4(1, 0, 0, 1);
vec4 colour_White = vec4(1, 1, 1, 1);


sTMData@ TMData;

CustomPlayerData[] OnlinePlayers;
CPInfo[] CPInfos;

class CPInfo
{
	uint[] Times;
	
	CPInfo()
	{
	}
}

void Log(int level, const string &in message)
{
	if(logDetailLevel >= level)
		print(message);
}

void Main() 
{
	Log(1, "Started");
	@m_font = Resources::GetFont(NumberFont);
	
	@TMData = sTMData();
	TMData.Update(null);
	
	GetUILayer();
}

void GetUILayer()
{
	Log(2, "Getting UI Layer");
	// These are all variables we'll need for updating
	CGameCtnApp@ app;
	CGameCtnNetwork@ Network;

	// These are required to retrieve data from the manialink we're using
	CGameManiaAppPlayground@ UIMgr;
	CGameUILayer@ UI_Data_Layer = null;

	
	// Get references to all the variables we'll need and ensure we don't get any null pointer access errors
	@app = GetApp();
	if(app is null || app.CurrentPlayground is null)
		return;

	@Network = app.Network;
	if(Network is null)
		return;
	
	// All this is needed to get the UI labels to retrieve the values we set in the manialink
	@UIMgr = cast<CGameManiaAppPlayground>(Network.ClientManiaAppPlayground); //This is ClientSide ManiaApp 
	if(UIMgr is null)
		return;

	for(uint i = 0; i < UIMgr.UILayers.Length; ++i)
	{
		auto layer = cast<CGameUILayer>(UIMgr.UILayers[i]);
		if(layer.ManialinkPageUtf8.Contains("UIModule_Knockout_KnockoutInfo"))
			@UI_Data_Layer = layer;
	}
	
	if(UI_Data_Layer is null)
		return;
	
	auto ML_localpage = cast<CGameManialinkPage>(UI_Data_Layer.LocalPage);
		if(ML_localpage is null)
			return;
	
	@lbl_Players = cast<CGameManialinkLabel>(ML_localpage.GetFirstChild("label-players"));
	@lbl_KOs = cast<CGameManialinkLabel>(ML_localpage.GetFirstChild("label-KOs"));
	
	if(lbl_Players is null || lbl_KOs is null)
		print("ERROR: Could not find all lables");
		
	Log(2, "UI Layer found");
}

void UpdateLabels()
{
	Log(5, "Updating labels");
	if(lbl_Players is null || lbl_KOs is null)
		GetUILayer();
	
	if(lbl_Players is null || lbl_KOs is null)
		return;
		
	int numPlayers = Text::ParseInt(lbl_Players.Value);
	int numKOs = GetNumKOs(numPlayers, lbl_KOs.Value);
	
	firstSafePosition = numPlayers - numKOs;
	
	Log(5, "First safe position: " + firstSafePosition);
}

int GetNumKOs(int numPlayers, const string &in KOString)
{
	if(KOString.Contains("NO KO"))
		return 0;
	else if(numPlayers > 16)
		return 4;
	else if(numPlayers > 8)
		return 2;
	else if(numPlayers > 1)
		return 1;
	else return 0;
}

CustomPlayerData@ GetPlayerData(const string &in Login)
{	
	for(int i = 0; i < OnlinePlayers.get_Length(); i++)
	{
		if(Login == OnlinePlayers[i].Login)
			return OnlinePlayers[i];
	}
	return null;
}




class CustomPlayerData
{
	string Login;
	int NumCPs;
	uint[] CPTimes;
	uint CurrentRaceTime;
	uint StartTime;
	uint LatestCPTime;
	
	CustomPlayerData()
	{
	}

	CustomPlayerData(const string &in input)
	{
		string[] Data = input.Split(",@,");
		uint leng = Data.get_Length();
		
		if(leng > 0)
			Login = Data[0];
		if(leng > 1)
			StartTime = Text::ParseInt(Data[1]);
		if(leng > 2)
			CurrentRaceTime = Text::ParseInt(Data[2]);
		if(leng > 3)
			NumCPs = Text::ParseInt(Data[3]);
		if(NumCPs > 0 && leng > 4)
		{
			string[] NumCPsString = Data[4].Split(",");
			for(uint i = 0; i < NumCPsString.get_Length(); i++)
			{
				uint CPTime = Text::ParseInt(NumCPsString[i]);
				if(CPTime > 0)
					CPTimes.InsertLast(CPTime);
			}
		}
	}
	
	bool CopyFrom(CustomPlayerData UpdatedPlayer, int NumberOfCheckpoints) // returns true if a new checkpoint has been passed
	{
		bool Result = false;
		if(NumCPs < UpdatedPlayer.NumCPs)
		{
			LatestCPTime = UpdatedPlayer.CPTimes[UpdatedPlayer.NumCPs -1];
			Log(4, "Player " + UpdatedPlayer.Login + " has new CP, index: " + UpdatedPlayer.NumCPs + " with time: " + LatestCPTime);
			Result = true;
		}
		
		NumCPs = UpdatedPlayer.NumCPs;
		CPTimes = UpdatedPlayer.CPTimes;
		CurrentRaceTime = UpdatedPlayer.CurrentRaceTime;
		StartTime = UpdatedPlayer.StartTime;
		
		return Result;
	}
}

void GetPlayersFromString(const string &in input)
{
	string[] PerPlayerString = input.Split(",$,$,");
	uint i = 0;
	uint j = 0;
	bool bFoundPlayer = false;
	
	CustomPlayerData[] lPlayers;
	
	for(i = 0; i < PerPlayerString.get_Length(); i++)
	{
		lPlayers.InsertLast(CustomPlayerData(PerPlayerString[i]));
	}
	
	if(OnlinePlayers.get_Length() > 0)
	{
		for(i = 0; i < lPlayers.get_Length(); i++)
		{
			bFoundPlayer = false;
			for(j = 0; j < OnlinePlayers.get_Length(); j++)
			{
				if(lPlayers[i].Login == OnlinePlayers[j].Login)
				{
					if(OnlinePlayers[j].CopyFrom(lPlayers[i], TMData.dMapInfo.NumberOfCheckpoints))
					{
						InsertCPTime(OnlinePlayers[j].LatestCPTime, OnlinePlayers[j].NumCPs);
					}
					bFoundPlayer = true;
					break;
				}
			}
			
			if(!bFoundPlayer)
			{
				Log(3, "Found new player: " + lPlayers[i].Login);
				OnlinePlayers.InsertLast(lPlayers[i]);
			}
		}
	}
	else
	{
		for(i = 0; i < lPlayers.get_Length(); i++)
		{
			Log(3, "Found new player (2): " + lPlayers[i].Login);
			OnlinePlayers.InsertLast(lPlayers[i]);
		}
	}
	
}


void RenderNextCPTime()
{
	if(CPInfos.Length == 0)
		return;
		
	if(currentPlayer is null || (currentPlayer.Login != currentPlayerID && currentPlayerID != ""))
	{
		@currentPlayer = GetPlayerData(currentPlayerID);
		
		if(currentPlayer is null)
		{
			Log(1, "Could not find player with ID: " + currentPlayerID);
			return;
		}
	}
	
	if(currentPlayer.CPTimes.Length == 0)
	{
		if(CPInfos.Length > 0 && CPInfos[0].Times.Length >= firstSafePosition)
		{
			timeDiff = currentPlayer.CurrentRaceTime - CPInfos[0].Times[firstSafePosition -1];
		}
	}
	else
	{
		int playerCPNum = currentPlayer.CPTimes.Length -1;
		if(CPInfos.Length > playerCPNum && CPInfos[playerCPNum + 1].Times.Length >= firstSafePosition) // next cp time
		{
			timeDiff = currentPlayer.CurrentRaceTime - CPInfos[playerCPNum + 1].Times[firstSafePosition -1];
		}
		else if(CPInfos[playerCPNum].Times.Length >= firstSafePosition)
		{
			int playerIndex = CPInfos[playerCPNum].Times.Find(currentPlayer.LatestCPTime);
			if(playerIndex == -1)
			{
				timeDiff = 0;
			}
			else if(playerIndex >= firstSafePosition) // player in ko
			{
				timeDiff = currentPlayer.LatestCPTime - CPInfos[playerCPNum].Times[firstSafePosition -1];
			}
			else
			{
				if(CPInfos[playerCPNum].Times.Length > 0 && CPInfos[playerCPNum].Times.Length > firstSafePosition)
					timeDiff = currentPlayer.LatestCPTime - CPInfos[playerCPNum].Times[firstSafePosition];
				else
					timeDiff = 0;
			}
		}
		else
		{
			timeDiff = currentPlayer.LatestCPTime - currentPlayer.CurrentRaceTime;
		}
	}
	
	if(currentPlayer.CPTimes.Length != currentPlayerCP)
	{
		//CalculateTimeDiff();
	}
	
	if(timeDiff == -1 && !bAlwaysRender)
		return;
	
	nvg::FontFace(m_font);
	if(timeDiff < 0)
		nvg::FillColor(colour_Red);
	else if(timeDiff > 0)
		nvg::FillColor(colour_Green);
	else
		nvg::FillColor(colour_White);
	nvg::TextAlign(nvg::Align::Middle | nvg::Align::Center);

	nvg::BeginPath();
	nvg::FontSize(fontSize);
	nvg::TextBox(0, YPos, XPos, GetFormattedTime(timeDiff));
}

string GetFormattedTime(int input)
{
	string Result = "";
	uint absTime = Math::Abs(input);
	Time::Info timestamp = Time::Parse(absTime);
	
	if(absTime > 999)
	{
		int seconds = absTime / 1000;
		int minutes = 0;
		
		if(seconds > 59)
		{
			minutes = seconds / 60;
			seconds = seconds - (minutes * 60);
		}
		
		int milliseconds = Math::Abs(absTime % 1000);
		
		string secondsPrefix = "";
		
		if(seconds < 10)
			secondsPrefix = "0";
		
		string milliPrefix = "";
		if(milliseconds < 10)
			milliPrefix = "00";
		else if(milliseconds < 100)
			milliPrefix = "0";
		
		Result = "" + minutes + ":" + secondsPrefix + seconds + "." + milliPrefix + milliseconds;
	}
	else
	{
		Result = "0:00." + absTime;
	}
	
	if(input < 0)
		Result = "-" + Result;
	
	return Result;
}


void CalculateTimeDiff()
{
	if(currentPlayer is null || (currentPlayer.Login != currentPlayerID && currentPlayerID != ""))
	{
		@currentPlayer = GetPlayerData(currentPlayerID);
		
		if(currentPlayer is null)
		{
			Log(1, "Could not find player with ID: " + currentPlayerID);
			return;
		}
	}
	
	if(currentPlayer !is null)
	{
		currentPlayerCP = currentPlayer.CPTimes.Length;
		currentPlayerCPTime = currentPlayer.LatestCPTime;
	}
	
	if(CPInfos.Length >= currentPlayerCP && CPInfos.Length > 0)
	{
		int tempCP = Math::Max(currentPlayerCP, 0);
		if(CPInfos[tempCP].Times.Length >= firstSafePosition) // We're behind so start showing some red deltas
		{
			Log(2, "Calculating live diff to next cp, in KO zone");
			currentPlayerCPTime = currentPlayer.CurrentRaceTime;
			targetCPTime = CPInfos[tempCP].Times[firstSafePosition];
			timeDiff = currentPlayerCPTime - targetCPTime;
		}
		else if(currentPlayerCP > 0 && CPInfos[currentPlayerCP - 1].Times.Length > firstSafePosition && currentPlayerCPTime > 0) // We should be good so find the first KO CP time
		{
			uint playerIndex = CPInfos[currentPlayerCP - 1].Times.Find(currentPlayerCPTime);
			if(playerIndex > firstSafePosition)
			{
				Log(2, "Calculating diff to next cp, in KO zone");
				targetCPTime = CPInfos[currentPlayerCP - 1].Times[firstSafePosition];
				timeDiff = currentPlayerCPTime - targetCPTime;
			}
			else if(CPInfos[currentPlayerCP - 1].Times.Length > firstSafePosition + 1)
			{
				Log(2, "Calculating diff to next cp, in safe zone");
				targetCPTime = CPInfos[currentPlayerCP - 1].Times[firstSafePosition + 1];
				timeDiff = currentPlayerCPTime - targetCPTime;
			}
			else
			{
				Log(2, "Calculating live diff to next cp, in safe zone");
				targetCPTime = currentPlayer.CurrentRaceTime;
				timeDiff = targetCPTime - currentPlayerCPTime;
			}
			
		}
		else
		{
			Log(2,"Not enough CPs available yet");
			targetCPTime = -1;
			timeDiff = -1;
		}
	}
	

	// if(currentPlayerCPTime < 1)
		// return;
		
		
	// Log(2, "Calculating diff for new CPNum: " + currentPlayerCP + " with player time: " + currentPlayerCPTime);
		
	// if(CPInfos.Length >= currentPlayerCP && currentPlayerCP > 0 && CPInfos[currentPlayerCP - 1].Times.Length >= firstSafePosition)
	// {
		// targetCPTime = CPInfos[currentPlayerCP - 1].Times[firstSafePosition - 1];
		// timeDiff = currentPlayerCPTime - targetCPTime;
		// Log(2, "Calculated diff is: " + timeDiff + " with target time: " + targetCPTime);
	// }
	// else
	// {
		// if(currentPlayerCP > 0 && CPInfos.Length >= currentPlayerCP)
			// Log(2, "Not enough CPs available yet for CPNum: " + currentPlayerCP + " target: " + firstSafePosition + " with length: " + CPInfos[currentPlayerCP - 1].Times.Length);
		// else
			// Log(2, "Not enough CPs available yet for CPNum: " + currentPlayerCP + " target: " + firstSafePosition);
			
		// targetCPTime = -1;
		// timeDiff = -1;
	// }
}

void InsertCPTime(uint CPTime, int CPNum)
{
	if(CPInfos.Length < uint(CPNum))
		CreateCPInfos();
		
	CPInfos[CPNum - 1].Times.InsertLast(CPTime);
	CPInfos[CPNum - 1].Times.SortAsc();
	
	Log(3, "Adding new CP time, CPNum: " + CPNum + " with time: " + CPTime + " total length for this CP at: " + CPInfos[CPNum - 1].Times.Length);
	
	//if(currentPlayerCP > 0)
		//CalculateTimeDiff();
	
	//if(currentPlayerCP > 0 && int(CPInfos[CPNum - 1].Times.Length) >=firstSafePosition && CPNum == currentPlayerCP && firstSafePosition > -1)
	//{
	//	targetCPTime = CPInfos[CPNum - 1].Times[firstSafePosition - 1];
	//	timeDiff = currentPlayerCPTime - targetCPTime;
	//	Log(4, "New time difference found for player, CPNum: " + CPNum + " total length for this CP at: " + CPInfos[CPNum - 1].Times.Length + " difference: " + timeDiff);
	//}
}

void CreateCPInfos()
{
	Log(1, "Creating CP Infos");
	
	print("-------- resetting CP infos");
	if(CPInfos.Length > 0)
	{
		for(int i = 0; i < CPInfos.Length; i++)
		{
			print("index: " + i + ", count: " + CPInfos[i].Times.Length);
			
			if(currentPlayer !is null && currentPlayer.CPTimes.Length > i)
			{
				print("player index: " + CPInfos[i].Times.Find(currentPlayer.CPTimes[i]));
			}
		}
	}
	
	CPInfos.RemoveRange(0,CPInfos.Length);
	if(TMData !is null)
	{
		for(int i = 0; i < TMData.dMapInfo.NumberOfCheckpoints+2; i++)
		{
			CPInfos.InsertLast(CPInfo());
		}
	}
	
	//OnlinePlayers.RemoveRange(0,OnlinePlayers.Length);
}

void EndOfRoundReset()
{
	Log(1, "End of round reset");
	currentPlayerCP = -1;
	currentPlayerCPTime = -1;
	targetCPTime = -1;
	timeDiff = -1;

	CreateCPInfos();
}

void FullReset()
{
	Log(1, "Full Reset");
	firstSafePosition = -1;
	EndOfRoundReset();
	
	OnlinePlayers.RemoveRange(0, OnlinePlayers.get_Length());
}


void Render()
{
	if(TMData !is null)
	{
		sTMData@ previous = TMData;
		
		@TMData = sTMData();
		TMData.Update(previous);
		TMData.Compare(previous);
		
		if(!bEnabled)
			return;
		
		currentPlayerID = TMData.dPlayerInfo.Login;
		
		if(!TMData.dServerInfo.CurGameModeStr.Contains("Knockout"))
			return;
			
		if(TMData.dEventInfo.PlayerStateChange)
			EndOfRoundReset();
			
		if(TMData.dEventInfo.MapChange)
			FullReset();
			
		if(TMData.dEventInfo.CheckpointChange)
		{
			//currentPlayerCP = TMData.dPlayerInfo.NumberOfCheckpointsPassed;
			//currentPlayerCPTime = TMData.dPlayerInfo.LatestCPTime;
			//timeDiff = -1;
			//Log(2, "Player reached new CPNum: " + currentPlayerCP + " with time: " + currentPlayerCPTime);
		}
		UpdateLabels();
		
		if(firstSafePosition < 1)
			return;
		
		GetPlayersFromString(TMData.dMLData.AllPlayerData);
		RenderNextCPTime();
	}
}




