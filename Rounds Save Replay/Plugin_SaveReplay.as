#name "Auto-save replay"
#author "AR_Thommie"
#category "Aurora"

[Setting name="Enabled"]
bool Enabled = true;

string SaveFolder = "Send To Mooney\\";
string ReplaysFolder = "\\Replays\\";
string UserFolder = "";

sTMData@ TMData;

void CheckFolders()
{
	UserFolder = IO::FromUserGameFolder("");
	
	if(UserFolder == "")
	{
		print("No replays found, could not locate user folder");
		return;
	}
		

	if(!IO::FolderExists(UserFolder + ReplaysFolder + SaveFolder))
		 IO::CreateFolder(UserFolder + ReplaysFolder + SaveFolder);
}

void Main() 
{
	CheckFolders();
	@TMData = sTMData();
	TMData.Update(null);
}

void WriteFile(string FileName)
{
	if(UserFolder == "")
		return;
	
	string File_To_Load = UserFolder + ReplaysFolder + SaveFolder + FileName + ".txt";
	IO::File file(File_To_Load,IO::FileMode::Write);
	file.Open(IO::FileMode::Write);
	
	file.WriteLine(TMData.dMLData.AllPlayerData);
	file.Close();
}

void SaveReplay()
{
	CGameCtnApp@ app;
	CGameCtnNetwork@ Network;
	CGamePlaygroundClientScriptAPI@ PlaygroundClientScriptAPI;
	
	@app = GetApp();
	if(app is null)
		return;
	@Network = app.Network;
	if(Network is null)
		return;
	@PlaygroundClientScriptAPI = Network.PlaygroundClientScriptAPI;
	if(PlaygroundClientScriptAPI is null)
		return;
		
	string FileName;
	Time::Info timestamp = Time::Parse(Time::get_Stamp());
	FileName = timestamp.Year + "-" + timestamp.Month + "-" + timestamp.Day + "_" + timestamp.Hour + "-" + timestamp.Minute + "-" + timestamp.Second + "_" + TMData.dMapInfo.MapName;
			
	WriteFile(FileName);
	if(PlaygroundClientScriptAPI.SavePrevReplay(SaveFolder + FileName))
	{}
	else if(PlaygroundClientScriptAPI.SaveReplay(SaveFolder + FileName))
	{}
	else
		print("Could not save replay");
}

void Render()
{
	if(TMData !is null && Enabled && TMData.dServerInfo.CurGameModeStr.Contains("TM_Rounds_Online"))
	{
		sTMData@ previous = TMData;
		
		@TMData = sTMData();
		TMData.Update(previous);
		TMData.Compare(previous);

		if(TMData.dEventInfo.EndRun)
			SaveReplay();
	}
}