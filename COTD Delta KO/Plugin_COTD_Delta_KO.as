[Setting name="Disable above playercount"]
int maxPlayerCount = 64;

[Setting name="Preview screen location"]
bool bShowTimer = false;

[Setting name="XPos"]
int XPos = 1920;

[Setting name="YPos"]
int YPos = 980;

[Setting name="Fontsize"]
int fontSize = 40;

[Setting name="Negative difference colour" color]
vec4 colour_Red = vec4(0, 1, 0, 1);

[Setting name="Positive difference colour" color]
vec4 colour_Green = vec4(1, 0, 0, 1);

[Setting name="Live difference colour" color]
vec4 colour_White = vec4(1, 1, 1, 1);

// To allow for showing the difference of spectated players
string currentPlayerID = "";
CustomPlayerData@ currentPlayer;

int firstSafePosition = -1; // This is the last position to qualify for the next round
int KOCount; // Number of KOs this round, 0 if warm-up or first round
int numPlayers; // Number of players in the round

string NumberFont = "DroidSans.ttf";
nvg::Font m_font;

CGameManialinkLabel@ lbl_Players; // The label containing the number of players
CGameManialinkLabel@ lbl_KOs; // The label containing the KO count

PlayerState::sTMData@ TMData; // The current PlayerState

CustomPlayerData[] OnlinePlayers; // All players in the server
CPInfo[] CPInfos; // All checkpoint times from all players

string ML = """
			<label pos="145 -81" z-index="0" size="1 1" text="1" style="TextValueSmallSm" valign="center2" halign="center" id="Playercount" opacity="0"/>
			<label pos="145 -81" z-index="0" size="1 1" text="1" style="TextValueSmallSm" valign="center2" halign="center" id="KOcount" opacity="0"/>
			
			<script><!-- #Include "TextLib" as TL 
			declare CMlLabel L1 <=> (Page.GetFirstChild("Playercount") as CMlLabel); 
			declare CMlLabel L2 <=> (Page.GetFirstChild("KOcount") as CMlLabel);
			declare netread Integer Net_Knockout_KnockoutInfo_PlayersNb for Teams[0] = 0;
			declare netread Integer Net_Knockout_KnockoutInfo_KOsNumber for Teams[0] = 0;
			
			while(True)
			{
				yield;
				
				L1.SetText(TL::ToText(Net_Knockout_KnockoutInfo_PlayersNb));
				L2.SetText(TL::ToText(Net_Knockout_KnockoutInfo_KOsNumber));
				
			}
			--></script>""";
			
// This contains the checkpoint times for all players on the server once they pass the corresponding checkpoint
class CPInfo
{
	uint[] Times;
	
	CPInfo()
	{
		Times.Reserve(64);
	}
}

void Main() 
{
	m_font = nvg::LoadFont(NumberFont);
	
	OnlinePlayers.Reserve(64);	
	GetUILayer();
}

// Get the number of players, KOcount and the firstSafePosition
void UpdateLabels()
{
	if(lbl_Players is null || lbl_KOs is null)
		GetUILayer();
	
	if(lbl_Players is null || lbl_KOs is null)
		return;
	
	numPlayers = Text::ParseInt(lbl_Players.Value);
	KOCount = Text::ParseInt(lbl_KOs.Value);
	
	int newSafePosition = numPlayers - KOCount;
	if(newSafePosition != firstSafePosition && KOCount > 0)
		EndOfRoundReset();
		
	firstSafePosition = newSafePosition;
}

// This gets the manually injected UI Layer to get the data from the manialink labels
void GetUILayer()
{
	// These are required to retrieve data from the manialink we're using
	CGameCtnApp@ app;
	CGameCtnNetwork@ Network;
	CGameManiaAppPlayground@ UIMgr;
	CGameUILayer@ UI_Data_Layer;
	CGamePlaygroundUIConfig@ clientUI;

	
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
		
	@clientUI = cast<CGamePlaygroundUIConfig>(UIMgr.ClientUI); //We access ClientSide UI class
	if(clientUI is null)
		return;
		
	@UI_Data_Layer = GetLayer(ML, "COTD_Data", UIMgr);
	
	auto ML_localpage = cast<CGameManialinkPage>(UI_Data_Layer.LocalPage); //We load Manialink page to function like "GetFirstChild"
	if(ML_localpage is null)
		return;

	@lbl_Players = cast<CGameManialinkLabel>(ML_localpage.GetFirstChild("Playercount"));
	@lbl_KOs = cast<CGameManialinkLabel>(ML_localpage.GetFirstChild("KOcount"));	
}

// Returns the layer in the player's UI or creates it if there is none (i.e. after leaving the menu), returns null if the LocalPage of the UILayer is null
	CGameUILayer@ GetLayer(wstring manialink, const string &in id, CGameManiaAppPlayground@ UIMgr)
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


// Tries to find the CustomPlayerData for the provided login
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
	string Login; // Used to search for a specific player
	int NumCPs; // Number of checkpoints passed by player
	uint[] CPTimes; // Contains all checkpoint times
	uint CurrentRaceTime; // The time of the current run
	uint StartTime; // The starttime of the current run
	uint LatestCPTime; // The time of the latest checkpoint the player has passed, 0 if no checkpoints have been passed
	bool bRestarted; // True when the player has just restarted the round (checkpoint times have been removed)

	CustomPlayerData() {} // Don't use this please

	// input is split by ",@,"  into Login",@,StartTime",@,CurrentRaceTime",@,NumCPs",@,CP0,CP1,CP2...
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
	
	// Copies the data from the updated string to the existing player
	bool CopyFrom(CustomPlayerData UpdatedPlayer) // returns true if a new checkpoint has been passed
	{
		bool Result = false; // Whether the player has passed a new checkpoint
		bRestarted = false;
		
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
			
			CPTimes.InsertLast(UpdatedPlayer.LatestCPTime);
			LatestCPTime = UpdatedPlayer.LatestCPTime;
			NumCPs = CPTimes.Length;
		}
		
		CurrentRaceTime = UpdatedPlayer.CurrentRaceTime;
		
		return Result;
	}
}

// This parses the manialink string into CustomPlayerData for each player, players are separated by ",$,$,"
void GetPlayersFromString(const string &in input)
{
	string[] PerPlayerString = input.Split(",$,$,");
	uint i = 0;
	uint j = 0;
	bool bFoundPlayer = false;
	
	CustomPlayerData lPlayer;
	
	for(i = 0; i < PerPlayerString.Length; i++)
	{
		lPlayer = CustomPlayerData(PerPlayerString[i]);
		if(OnlinePlayers.Length > i && OnlinePlayers[i].Login == lPlayer.Login)
			j = i;
		else if(OnlinePlayers.Length > j && OnlinePlayers[j].Login == lPlayer.Login)
			j = j;
		else
			j = 0;
			
		bFoundPlayer = false;			
		for(; j < OnlinePlayers.get_Length(); j++)
		{
			if(lPlayer.Login == OnlinePlayers[j].Login)
			{
				if(OnlinePlayers[j].CopyFrom(lPlayer))
					InsertCPTime(OnlinePlayers[j].LatestCPTime, OnlinePlayers[j].NumCPs);
				
				bFoundPlayer = true;
				break;
			}
		}
		if(!bFoundPlayer)
		{
			OnlinePlayers.InsertLast(lPlayer);
			
			if(lPlayer.NumCPs > 0)
			{
				for(int x = 0; x < lPlayer.NumCPs; x++)
				{
					InsertCPTime(lPlayer.CPTimes[x], x + 1);
				}
			}
		}
	}
}


// Renders 0:00.000 on screen to adjust the position in the settings
void RenderPreviewTime()
{
	if(bShowTimer)
	{
		nvg::FontFace(m_font);
		nvg::FillColor(colour_White);
		nvg::TextAlign(nvg::Align::Middle | nvg::Align::Center);

		nvg::BeginPath();
		nvg::FontSize(fontSize);
		nvg::TextBox(0, YPos, XPos, GetFormattedTime(0));
	}
}

// Renders the difference between 
// 		(1) player time and current race time if the player is ahead of the first KO position (positive amount, white) (player checkpoint)
//		(2) firstSafePosition time and current race time if the player has not yet passed the checkpoint (negative amount, white) (player checkpoint +1)
//		(3) player cp time and first KO position cp time if both have crossed the checkpoint (positive amount, green) (player checkpoint)
// 		(4) firstSafePosition and player cp time if both have crossed the checkpoint (negative amount, red) (player checkpoint +1)
void RenderNextCPTime()
{
	if(CPInfos.Length == 0 && KOCount == 0)
		return;
		
	if(currentPlayer is null || (currentPlayer.Login != currentPlayerID && currentPlayerID != ""))
	{
		@currentPlayer = GetPlayerData(currentPlayerID);
		
		if(currentPlayer is null)
		{
			print("Could not find player with ID: " + currentPlayerID);
			return;
		}
	}
	
	if(currentPlayer.bRestarted)
		EndOfRoundReset();
		
	bool bLiveTime;
	int timeDiff = 0;
	
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
		
		if(playerCPNum < 0 || firstSafePosition < 0)
			return;
			
		if(int(CPInfos.Length) > playerCPNum && int(CPInfos[playerCPNum + 1].Times.Length) >= firstSafePosition) // next cp time
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
	nvg::TextBox(0, YPos, XPos, GetFormattedTime(timeDiff));
}


void InsertCPTime(uint CPTime, int CPNum)
{
	if(KOCount < 1)
		return;
		
	if(CPInfos.Length < uint(CPNum))
		CreateCPInfos();
		
	CPInfos[CPNum - 1].Times.InsertLast(CPTime);
	if(int(CPInfos[CPNum - 1].Times.Length) > firstSafePosition - 1)
		CPInfos[CPNum - 1].Times.SortAsc();	// We need to sort because of delays from people with slow internet
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

// Reset some thing when the round ends
void EndOfRoundReset()
{
	firstSafePosition = -1;
	CreateCPInfos();
}


void Update(float dt)
{
	PlayerState::sTMData@ previous = TMData;
	@TMData = PlayerState::GetRaceData();
	
	RenderPreviewTime();
	
	if(TMData !is null)
	{	
		if(previous !is null && previous.UpdateNumber == TMData.UpdateNumber) // getting the same data twice so skip this
			return;
		
		if(!TMData.dServerInfo.CurGameModeStr.Contains("Knockout")) // Ignore everything if we're not in any form of knockout gamemode
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
		
		if(firstSafePosition < 0 || KOCount < 1) // No KOs and no safe position, something is wrong
			return;
		
		if(numPlayers > maxPlayerCount)
			return;
			
		GetPlayersFromString(TMData.dMLData.AllPlayerData);
		RenderNextCPTime();
	}
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



