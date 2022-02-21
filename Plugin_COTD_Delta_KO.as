#name "COTD Delta KO"
#author "AR_Thommie"
#category "Aurora"

#include "AR_Data.as"

[Setting name="Enabled"]
bool bEnabled = true;

[Setting name="XPos"]
int XPos = 50;

[Setting name="YPos"]
int YPos = 350;

[Setting name="Fontsize"]
int fontSize = 25;

[Setting name="Negative difference colour" color]
vec4 colour_Red = vec4(0, 1, 0, 1);

[Setting name="Positive difference colour" color]
vec4 colour_Green = vec4(1, 0, 0, 1);

[Setting name="Live difference colour" color]
vec4 colour_White = vec4(1, 1, 1, 1);


[Setting name="Log detail level"]
int logDetailLevel = 0;

[Setting name="Count retired"]
int countRetired;

string currentPlayerID = "";
CustomPlayerData@ currentPlayer;

int firstSafePosition = -1;
int targetCPTime = -1;
int KOCount = -1;

string NumberFont = "DroidSans.ttf";
Resources::Font@ m_font;

CGameManialinkLabel@ lbl_Players;
CGameManialinkLabel@ lbl_KOs;

int numMapCPs;

int lastDiff = 0;


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
	@m_font = Resources::GetFont(NumberFont);
	
	@TMData = sTMData();
	TMData.Update(null);
	
	GetUILayer();
}

void GetUILayer()
{
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
		{
			@UI_Data_Layer = layer;
			break;
		}
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
}

void UpdateLabels()
{
	if(lbl_Players is null || lbl_KOs is null)
		GetUILayer();
	
	if(lbl_Players is null || lbl_KOs is null)
		return;
		
	int numPlayers = Text::ParseInt(lbl_Players.Value);
	KOCount = GetNumKOs(numPlayers, lbl_KOs.Value);
	
	int newSafePosition = numPlayers - KOCount;
	if(newSafePosition != firstSafePosition)
		EndOfRoundReset();
	
	firstSafePosition = newSafePosition;
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
	for(uint i = 0; i < OnlinePlayers.get_Length(); i++)
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
	bool bRestarted;
	bool bFinished;
	bool bNewCP;
	bool bDriving;
	
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
			LatestCPTime = CPTimes[NumCPs -1];
		}
	}
	
	bool CopyFrom(CustomPlayerData UpdatedPlayer) // returns true if a new checkpoint has been passed
	{
		if(Login.Length < 1)
			return false;
			
		bool Result = false;
		
		bRestarted = false;
		bNewCP = false;
		
		
		if(UpdatedPlayer.NumCPs < NumCPs || StartTime != UpdatedPlayer.StartTime) // we've restarted
		{
			bRestarted = true;
			
			StartTime = UpdatedPlayer.StartTime;
			
			if(CPTimes.Length > 0)
				CPTimes.RemoveRange(0,CPTimes.Length);
				
			LatestCPTime = 0;
			NumCPs = 0;
		}
		else if(UpdatedPlayer.NumCPs > NumCPs) // we've passed a new cp
		{
			Result = true;
			bNewCP = true;
			
			CPTimes.InsertLast(UpdatedPlayer.LatestCPTime);
			LatestCPTime = UpdatedPlayer.LatestCPTime;
			NumCPs = CPTimes.Length;
			
			Log(4, "Player " + UpdatedPlayer.Login + " has new CP, index: " + UpdatedPlayer.NumCPs + " with time: " + LatestCPTime);
		}
		
		if(CurrentRaceTime == UpdatedPlayer.CurrentRaceTime)
		{
			if(bDriving)
			{
				if(!bFinished)
				{
					bFinished = true;
				}
			}
			else
				bFinished = false;
		}
		else
			bFinished = false;
		
		
		bDriving = CurrentRaceTime != UpdatedPlayer.CurrentRaceTime;
		CurrentRaceTime = UpdatedPlayer.CurrentRaceTime;
		
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
			if(OnlinePlayers[i].Login == lPlayers[i].Login)
				j = i;
			else
				j = 0;
				
			bFoundPlayer = false;
			
			for(; j < OnlinePlayers.get_Length(); j++)
			{
				if(lPlayers[i].Login == OnlinePlayers[j].Login)
				{
					OnlinePlayers[j].CopyFrom(lPlayers[i]);
					if(OnlinePlayers[j].bNewCP)
					{
						InsertCPTime(OnlinePlayers[j].LatestCPTime, OnlinePlayers[j].NumCPs);
					}
					if(OnlinePlayers[j].bFinished && OnlinePlayers[j].NumCPs < numMapCPs)
					{
						countRetired++;
					}
					bFoundPlayer = true;
					break;
				}
			}
			
			if(!bFoundPlayer)
			{
				OnlinePlayers.InsertLast(lPlayers[i]);
				
				if(lPlayers[i].NumCPs > 0)
				{
					for(int x = 0; x < lPlayers[i].NumCPs; x++)
					{
						InsertCPTime(lPlayers[i].CPTimes[x], x + 1);
					}
				}
			}
		}
	}
	else
	{
		for(i = 0; i < lPlayers.get_Length(); i++)
		{
			OnlinePlayers.InsertLast(lPlayers[i]);
			
			if(lPlayers[i].NumCPs > 0)
			{
				for(int x = 0; x < lPlayers[i].NumCPs; x++)
				{
					InsertCPTime(lPlayers[i].CPTimes[x], x + 1);
				}
			}
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
	
	if(currentPlayer.bRestarted)
		EndOfRoundReset();
		
	bool bLiveTime;
	int timeDiff = 0;
	
	if(currentPlayer.CurrentRaceTime < 0 && KOCount > 0)
		KOCount = 0;
	
	
	if(currentPlayer.CPTimes.Length == 0) // player has not passed a CP
	{
		if(CPInfos.Length > 0 && int(CPInfos[0].Times.Length) >= firstSafePosition && firstSafePosition > 0) // check if enough people have already passed the first CP
		{
			timeDiff = currentPlayer.CurrentRaceTime - CPInfos[0].Times[firstSafePosition -1];
			bLiveTime = true;
		}
		else
		{
			timeDiff = 0;
		}
	}
	else // player has passed at least one cp
	{
		int playerCPNum = currentPlayer.CPTimes.Length -1;
		if(int(CPInfos.Length) > playerCPNum +1 && int(CPInfos[playerCPNum + 1].Times.Length) >= firstSafePosition) // next cp time
		{
			timeDiff = currentPlayer.CurrentRaceTime - CPInfos[playerCPNum + 1].Times[firstSafePosition -1];
			bLiveTime = true;
		}
		else if(int(CPInfos[playerCPNum].Times.Length) >= firstSafePosition) // At least all the safe people have passed the same CP as the player
		{
			int playerIndex = CPInfos[playerCPNum].Times.Find(currentPlayer.LatestCPTime);
			if(playerIndex == -1) // Somehow the player has passed this CP but we can't find their time in the list
			{
				timeDiff = 0;
			}
			else if(playerIndex >= firstSafePosition) // player in ko
			{
				timeDiff = currentPlayer.LatestCPTime - CPInfos[playerCPNum].Times[firstSafePosition -1];
			}
			else // player in safe position
			{
				if(CPInfos[playerCPNum].Times.Length > 0 && int(CPInfos[playerCPNum].Times.Length) > firstSafePosition) // Check if the first KO person has already passed the CP
				{
					timeDiff = currentPlayer.LatestCPTime - CPInfos[playerCPNum].Times[firstSafePosition];
				}
				else // We've passed the CP, so has the last safe person, but not the first KO position
				{
					timeDiff = currentPlayer.LatestCPTime - currentPlayer.CurrentRaceTime;
					bLiveTime = true;
				}
			}
		}
		else
		{
			timeDiff = currentPlayer.LatestCPTime - currentPlayer.CurrentRaceTime;
			bLiveTime = true;
		}
	}
	
	int prevCP = currentPlayer.CPTimes.Length - 2;
	if(prevCP > -1 && CPInfos[prevCP].Times.Length > 0)
		CPInfos[prevCP].Times.RemoveRange(0,CPInfos[prevCP].Times.Length);
	
	if(timeDiff > 0)
		lastDiff = timeDiff;
	
	nvg::FontFace(m_font);
	if(bLiveTime)
		nvg::FillColor(colour_White);
	else if(timeDiff < 0)
		nvg::FillColor(colour_Red);
	else if(timeDiff > 0)
		nvg::FillColor(colour_Green);
	else
		nvg::FillColor(colour_White);
	nvg::TextAlign(nvg::Align::Middle | nvg::Align::Center);

	nvg::BeginPath();
	nvg::FontSize(fontSize);
	
	string drawString = GetFormattedTime(timeDiff);
	
	if(countRetired > KOCount && KOCount > -1)
		drawString = "Safe";
			
	nvg::TextBox(0, YPos, XPos, drawString);
}

CSmPlayer@ GetViewingPlayer()
{
	auto playground = GetApp().CurrentPlayground;
	if (playground is null || playground.GameTerminals.Length != 1) {
		return null;
	}
	return cast<CSmPlayer>(playground.GameTerminals[0].GUIPlayer);
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
		string prefix = "0:00.";
		if(absTime < 10)
			prefix = prefix + "00";
		else if (absTime < 100)
			prefix = prefix + "0";
			
		Result = prefix + absTime;
	}
	
	if(input < 0)
		Result = "-" + Result;
	
	return Result;
}



void InsertCPTime(uint CPTime, int CPNum)
{
	if(CPInfos.Length < uint(CPNum))
		CreateCPInfos();
		
	if(currentPlayer !is null && CPNum < currentPlayer.NumCPs)
		return;
		
	CPInfos[CPNum - 1].Times.InsertLast(CPTime);
	if(int(CPInfos[CPNum - 1].Times.Length) > firstSafePosition - 1)
		CPInfos[CPNum - 1].Times.SortAsc();	
}

void CreateCPInfos()
{
	CPInfos.RemoveRange(0,CPInfos.Length);
	if(TMData !is null)
	{
		for(int i = 0; i < TMData.dMapInfo.NumberOfCheckpoints+2; i++)
		{
			CPInfos.InsertLast(CPInfo());
		}
	}
}

void EndOfRoundReset()
{
	firstSafePosition = -1;
	countRetired = 0;

	CreateCPInfos();
}


void Render()
{
	if(TMData !is null)
	{
		sTMData@ previous = TMData;
		
		@TMData = sTMData();
		TMData.Update(previous);
		TMData.Compare(previous);
		
		numMapCPs = TMData.dMapInfo.NumberOfCheckpoints;
		
		if(previous.UpdateNumber == TMData.UpdateNumber) // getting the same data twice so skip this
			return;
		
		if(!bEnabled)
			return;
		
		if(!TMData.dServerInfo.CurGameModeStr.Contains("Knockout"))
		{
			if(OnlinePlayers.Length > 0)
				OnlinePlayers.RemoveRange(0, OnlinePlayers.get_Length());
			return;		
		}
		
		CSmPlayer@ viewPlayer;
		@viewPlayer	= GetViewingPlayer();

		if(viewPlayer !is null)
			currentPlayerID = viewPlayer.User.Login;
		else
			currentPlayerID = TMData.dPlayerInfo.Login;

		UpdateLabels();
		
		if(firstSafePosition < 1)
			return;
		
		GetPlayersFromString(TMData.dMLData.AllPlayerData);
		RenderNextCPTime();
	}
}




