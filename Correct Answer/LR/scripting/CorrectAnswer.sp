#include <lvl_ranks>
#include <csgo_colors>

#include "data/data.sp"

public Plugin myinfo = 
{ 
	name = "Correct Answer", 
	author = "Palonez", 
	description = "The plugin gives a reward to the one who first entered the specified word correctly", 
	version = "1.2",
	url = "https://github.com/Quake1011" 
};

bool bCanSend, bScramble;
char sWord[256], sTag[128];
int iReward;
float fDelay, fTime;
ArrayList word;

public void OnPluginStart()
{
	ConVar cvar;
	
	HookConVarChange(cvar = CreateConVar("correct_reward", "100-500", "Величина награды. Может принимать диапазон значений[200-700] или конкретное значение[400]"), OnCVChange);
	char temp[2*11+1], intgr[2][11];
	GetConVarString(cvar, temp, sizeof(temp));
	if(StrContains(temp, "-", true) != -1)
	{
		ExplodeString(temp, "-", intgr, sizeof(intgr), sizeof(intgr[]));
		iReward = GetRandomInt(StringToInt(intgr[0]), StringToInt(intgr[1]));
	}
	iReward = StringToInt(temp);
	
	float x = 1.0
	HookConVarChange(cvar = CreateConVar("correct_delay", "30.0", "Время между генерацией нового слова", _, true, x+1.0), OnCVChange1);
	fDelay = GetConVarFloat(cvar);
	
	HookConVarChange(cvar = CreateConVar("correct_time_to_answer", "15.0", "Время на ответ", _, true, x), OnCVChange2);
	fTime = GetConVarFloat(cvar);
	
	HookConVarChange(cvar = CreateConVar("correct_scramble", "1", "Пемешивать буквы в словах? [0 - Нет \\ 1 - Да]"), OnCVChange3);
	bScramble = GetConVarBool(cvar);
	if(bScramble) word = CreateArray(64);
	
	HookConVarChange(cvar = CreateConVar("correct_tag", "{RED}[{GREEN}ANSWER{RED}]{DEFAULT}", "Тег плагина"), OnCVChange4);
	GetConVarString(cvar, sTag, sizeof(sTag));
	
	CreateTimer(fDelay, Rotation, _, TIMER_REPEAT);
	
	HookEvent("player_say", PlayerSay);
	
	AutoExecConfig(true, "CorrectAnswer");
}

public void OnCVChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	char temp[2*11+1], intgr[2][11];
	GetConVarString(convar, temp, sizeof(temp));
	if(StrContains(temp, "-", true) != -1)
	{
		ExplodeString(temp, "-", intgr, sizeof(intgr), sizeof(intgr[]));
		iReward = GetRandomInt(StringToInt(intgr[0]), StringToInt(intgr[1]));
	}
	iReward = StringToInt(temp);
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
	if(bScramble) 
		word = CreateArray(64);
	else 
		delete word;
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
			CGOPrintToChatAll("%s Игрок {OLIVE}%N{DEFAULT} правильно ввел слово \"{GREEN}%s{DEFAULT}\" и получил {RED}%d{DEFAULT} опыта",sTag, client, sWord, iReward)
			bCanSend = false;
		}
	}
	return Plugin_Continue;
}

public Action Rotation(Handle hTimer)
{
	int random = GetRandomInt(0, sizeof(Dictionary) - 1);
	strcopy(sWord, sizeof(sWord), Dictionary[random]);
	TrimString(sWord);

	LogMessage(sWord);

	if(bScramble)
	{

		bool cyrillic;
		if(65 <= RoundToFloor(float(sWord[0])) <= 90 || 97 <= RoundToFloor(float(sWord[0])) <= 122)
			cyrillic = false;
		else if(192 <= RoundToFloor(float(sWord[0])) <= 255)
			cyrillic = true;	
		else
		{	
			LogMessage("Unsupported word \"%s\" on array line:%d | index: %d", sWord, random+3, random);
			LogMessage("Delete the word and reload plugin");
			return Plugin_Stop;
		}
		
		word.Clear();
		
		if(cyrillic)
		{
			for(int i = 0; i < strlen(sWord)-1; i+=2)
			{
				char temp[2];
				temp[0] = sWord[i];
				temp[1] = sWord[i+1];
				word.PushString(temp);
			}
			
			for(int i = 0 ; i < 3; i++)
				word.Sort(Sort_Random, Sort_String);
		}
		else
		{
			for(int i = 0; i < strlen(sWord); i++)
				word.Push(RoundToFloor(float(sWord[i])));

			for(int i = 0 ; i < 3; i++)
				word.Sort(Sort_Random, Sort_Integer);
		}
		
		char temp[6], abs[256];
		for(int i = 0; i < word.Length; i++)
		{
			Format(temp, sizeof(temp), "%s", word.Get(i))
			StrCat(abs, sizeof(abs), temp);
		}		

		CGOPrintToChatAll("%s Напиши правильно слово \"{GREEN}%s{DEFAULT}\" и получи {RED}%d{DEFAULT} опыта",sTag, abs, iReward);
	}
	else CGOPrintToChatAll("%s Напиши слово \"{GREEN}%s{DEFAULT}\" и получи {RED}%d{DEFAULT} опыта",sTag, sWord, iReward);
	bCanSend = true;
	
	CreateTimer(fTime, TimeToAnswer);
	return Plugin_Continue;
}

public Action TimeToAnswer(Handle hTimer)
{
	if(bCanSend) CGOPrintToChatAll("%s Время вышло, никто не ответил", sTag);
	bCanSend = false;
	return Plugin_Continue;
}