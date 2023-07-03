#include <lvl_ranks>
#include <csgo_colors>

public Plugin myinfo = 
{ 
	name = "Correct Answer", 
	author = "Palonez", 
	description = "The plugin gives a reward to the one who first entered the specified word correctly", 
	version = "1.3",
	url = "https://github.com/Quake1011" 
};

bool bCanSend, bScramble;
char sWord[256], sTag[128];
int iReward, diap[2];
float fDelay, fTime;
ArrayList Dictionary;

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
	
	CreateTimer(fDelay, Rotation, _, TIMER_REPEAT);
	
	HookEvent("player_say", PlayerSay);
	
	LoadTranslations("CorrectAnswer.phrases");
	
	AutoExecConfig(true, "CorrectAnswer");
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
	GetConVarString(convar, sTag, sizeof(sTag));
}

public void OnCVChange4(ConVar convar, const char[] oldValue, const char[] newValue)
{
	bScramble = GetConVarBool(convar);
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
			LR_ChangeClientValue(client, iReward);
			CGOPrintToChatAll("%t", "ph1" ,sTag, client, sWord, iReward);
			bCanSend = !bCanSend;
		}
	}
	return Plugin_Continue;
}

public Action Rotation(Handle hTimer)
{
	Dictionary.GetString(GetRandomInt(0, Dictionary.Length-1), sWord, sizeof(sWord));
	iReward = GetRandomInt(diap[0], diap[1]);
	
	if(bScramble)
	{
		SortRandomString(sWord);
		CGOPrintToChatAll("%t", "ph2", sTag, sWord, iReward);
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