#include <shop>
#include <csgo_colors>

public Plugin myinfo = 
{ 
	name = "Correct Answer", 
	author = "Palonez", 
	description = "The plugin gives a reward to the one who first entered the specified word correctly", 
	version = "1.4",
	url = "https://github.com/Quake1011" 
};

bool bCanSend, bScramble, bRateStatus;
char sWord[256], sTag[128], sTableName[256], sQuery[256];
int iReward, diap[2];
float fDelay, fTime, fRateTime;
ArrayList Dictionary;
Database db;
Handle hTOP3;

public void OnPluginStart()
{
	char sFile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sFile, sizeof(sFile), "configs/dictionary.txt");
	File hFile = OpenFile(sFile, "r");
	if(hFile != null)
	{
		Dictionary = CreateArray(256);
		char[] tmp = new char[Dictionary.BlockSize];
		do
		{
			hFile.ReadLine(tmp, Dictionary.BlockSize-1);
			TrimString(tmp);
			Dictionary.PushString(tmp);
		} while(!hFile.EndOfFile());
		delete hFile;
	}
	else 
	{
		SetFailState("Cant open file \"configs/dictionary.txt\"");
		return;
	}
	
	ConVar cvar;
	HookConVarChange(cvar = CreateConVar("correct_reward", "100-500", "Величина награды. Может принимать диапазон значений[200-700] или конкретное значение[400]"), OnCVChange);
	GetRandom(cvar);
	
	HookConVarChange(cvar = CreateConVar("correct_delay", "30.0", "Время между генерацией нового слова"), OnCVChange1);
	fDelay = GetConVarFloat(cvar);
	
	HookConVarChange(cvar = CreateConVar("correct_time_to_answer", "15.0", "Время на ответ"), OnCVChange2);
	fTime = GetConVarFloat(cvar);
	
	HookConVarChange(cvar = CreateConVar("correct_scramble", "1", "Перемешивать буквы в словах? [0 - Нет \\ 1 - Да]"), OnCVChange3);
	bScramble = GetConVarBool(cvar);
	
	HookConVarChange(cvar = CreateConVar("correct_tag", "{RED}[{GREEN}ANSWER{RED}]{DEFAULT}", "Тег плагина"), OnCVChange4);
	GetConVarString(cvar, sTag, sizeof(sTag));
	
	HookConVarChange(cvar = CreateConVar("correct_table_name", "CorrectAnswer_Rating", "Имя таблицы рейтинга в базе"), OnCVChange5);
	GetConVarString(cvar, sTableName, sizeof(sTableName));
	
	HookConVarChange(cvar = CreateConVar("correct_rating_status", "1", "Включено ли периодическое отображение рейтинга в чате"), OnCVChange6);
	bRateStatus = GetConVarBool(cvar);
	
	HookConVarChange(cvar = CreateConVar("correct_rating_rotation", "50.0", "Время между показами рейтинга"), OnCVChange7);
	fRateTime = GetConVarFloat(cvar);
	
	Database.Connect(SQLConnect, "correct_answer");
	
	CreateTimer(fDelay, Rotation, _, TIMER_REPEAT);
	if(bRateStatus) hTOP3 = CreateTimer(fRateTime, OutputTOP3, _, TIMER_REPEAT);
	else if(hTOP3 != null) hTOP3 = null;
	
	HookEvent("player_say", PlayerSay);
	
	LoadTranslations("CorrectAnswer.phrases");
	
	AutoExecConfig(true, "CorrectAnswer");
}

public void SQLConnect(Database hdb, const char[] error, any data)
{
	if(hdb != null && !error[0]) 
	{
		db = hdb;
		db.SetCharset("utf8");
		Format(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `%s`(\
										`steam` VARCHAR(22) PRIMARY KEY,\
										`name` VARCHAR(%d),\
										`correct_answers` INTEGER(11) DEFAULT 0)", sTableName, MAX_NAME_LENGTH);
		SQL_FastQuery(db, sQuery);
	}
	else
	{
		SetFailState("Cant connect to database. Please check the section \"correct_answer\" in databases.cfg");
		return;
	}
}

public void OnCVChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetRandom(convar);
}

public void OnCVChange1(ConVar convar, const char[] oldValue, const char[] newValue)
{
	fDelay = GetConVarFloat(convar);
}

public void OnCVChange2(ConVar convar, const char[] oldValue, const char[] newValue)
{
	fTime = GetConVarFloat(convar);
}

public void OnCVChange3(ConVar convar, const char[] oldValue, const char[] newValue)
{
	bScramble = GetConVarBool(convar);
}

public void OnCVChange4(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetConVarString(convar, sTag, sizeof(sTag));
}

public void OnCVChange5(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetConVarString(convar, sTableName, sizeof(sTableName));
}

public void OnCVChange6(ConVar convar, const char[] oldValue, const char[] newValue)
{
	bRateStatus = GetConVarBool(convar);
	if(!bRateStatus && hTOP3 != null)
		hTOP3 = null;
}

public void OnCVChange7(ConVar convar, const char[] oldValue, const char[] newValue)
{
	fRateTime = GetConVarFloat(convar);
}

public Action PlayerSay(Event hEvent, const char[] sEvent, bool bdb)
{
	int client = GetClientOfUserId(hEvent.GetInt("userid"));
	char text[256];
	hEvent.GetString("text", text, sizeof(text));
	
	if(0 < client <= MaxClients && IsClientInGame(client) && bCanSend)
	{
		if(strcmp(text, sWord, true) == 0)
		{
			CGOPrintToChatAll("%t", "ph1" ,sTag, client, sWord, Shop_GiveClientCredits(client, iReward));
			bCanSend = !bCanSend;
			AddClientScore(client);
		}
	}
	return Plugin_Continue;
}

void AddClientScore(int client)
{
	if(db != null)
	{
		char sAuth[22];
		GetClientAuthId(client, AuthId_Steam2, sAuth, sizeof(sAuth));
		Format(sQuery, sizeof(sQuery), "SELECT * FROM `%s` WHERE `steam` = '%s'", sTableName, sAuth);
		DBResultSet result = SQL_Query(db, sQuery);
		if(result != null && result.HasResults && result.RowCount == 1) Format(sQuery, sizeof(sQuery), "UPDATE `%s` SET `correct_answers` = `correct_answers`+1 WHERE `steam` = '%s'", sTableName, sAuth);
		else Format(sQuery, sizeof(sQuery), "INSERT INTO `%s` (`steam`, `name`, `correct_answers`) VALUES ('%s', '%N', 1)", sTableName, sAuth, client);
		SQL_FastQuery(db, sQuery);
	}
}

public Action OutputTOP3(Handle hTimer)
{
	Format(sQuery, sizeof(sQuery), "SELECT `name`, `correct_answers` FROM `%s` ORDER BY `correct_answers` DESC LIMIT 3", sTableName);
	DBResultSet result = SQL_Query(db, sQuery);
	if(result != null && result.HasResults)
	{
		if(result.RowCount)
		{
			int i = 1;
			char name[MAX_NAME_LENGTH], bf[1024], buffer[256];
			Format(bf, sizeof(bf), "%t\n", "ph5", sTag);
			result.FetchRow();
			do
			{
				result.FetchString(0, name, sizeof(name));
				Format(buffer, sizeof(buffer), "%t\n","ph6", i, name, result.FetchInt(1));
				StrCat(bf, sizeof(bf), buffer);
				i++;
			} while(result.FetchRow());
			TrimString(bf);
			CGOPrintToChatAll(bf);
		}
	}
	delete result;
	return Plugin_Continue;
}

public Action Rotation(Handle hTimer)
{
	Dictionary.GetString(GetRandomInt(0, Dictionary.Length-1), sWord, sizeof(sWord));
	iReward = GetRandomInt(diap[0], diap[1]);
	
	if(bScramble)
	{
		char[] tempword = new char[sizeof(sWord)-1];
		strcopy(tempword, sizeof(sWord)-1, sWord);
		SortRandomString(tempword);
		CGOPrintToChatAll("%t", "ph2", sTag, tempword, iReward);
	}
	else CGOPrintToChatAll("%t", "ph3", sTag, sWord, iReward);
	bCanSend = true;
	
	CreateTimer(fTime, TimeToAnswer);
	return Plugin_Continue;
}

public Action TimeToAnswer(Handle hTimer)
{
	if(bCanSend) CGOPrintToChatAll("%t", "ph4", sTag);
	bCanSend = false;
	return Plugin_Continue;
}

stock void SortRandomString(char[] szText) // спасибо https://hlmod.net/members/komashchenko.49508/
{
    int iTextLen = strlen(szText);
    int[] iTextSymbolPos = new int[iTextLen];
    int iSymbols = 0;
    char[] szTextSorted = new char[iTextLen];
    
    for(int i = 0; i < iTextLen;)
    {
        iTextSymbolPos[iSymbols++] = i;
        i += GetCharBytes(szText[i]);
    }
    
    SortIntegers(iTextSymbolPos, iSymbols, Sort_Random);
    
    for(int i = 0, k = 0; i < iSymbols; i++)
    {
        int iBytes = GetCharBytes(szText[iTextSymbolPos[i]]);
        for(int u = 0; u < iBytes; u++)
            szTextSorted[k++] = szText[iTextSymbolPos[i] + u];
    }
    
    strcopy(szText, iTextLen + 1, szTextSorted);
}

stock void GetRandom(ConVar cvar)
{
	char temp[2*11-1];
	GetConVarString(cvar, temp, sizeof(temp));
	if(StrContains(temp, "-", true) != -1)
	{
		char intgr[2][11];
		ExplodeString(temp, "-", intgr, sizeof(intgr), sizeof(intgr[]));
		diap[0] = StringToInt(intgr[0]);
		diap[1] = StringToInt(intgr[1]);
	}
	diap[0] = diap[1] = StringToInt(temp);
}