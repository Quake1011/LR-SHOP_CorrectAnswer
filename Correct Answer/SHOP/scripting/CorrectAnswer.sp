#include <shop>
#include <csgo_colors>

#include "data/data.sp"

#define REW 400
#define DELAY 30.0
#define TIME_TO_ANSWER 15.0

public Plugin myinfo = 
{ 
	name = "Correct Answer", 
	author = "Palonez", 
	description = "The plugin gives a reward to the one who first entered the specified word correctly", 
	version = "1.1",
	url = "https://github.com/Quake1011" 
};

bool bCanSend;
char sWord[sizeof(Dictionary) - 1];

public void OnPluginStart()
{
	CreateTimer(DELAY, Rotation, _, TIMER_REPEAT);
	
	HookEvent("player_say", PlayerSay);
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
			CGOPrintToChatAll("Игрок {OLIVE}%N{DEFAULT} правильно ввел слово \"{GREEN}%s{DEFAULT}\" и получил {RED}%d{DEFAULT} кредитов", client, sWord, Shop_GiveClientCredits(client, REW))
			bCanSend = false;
		}
	}
	return Plugin_Continue;
}

public Action Rotation(Handle hTimer)
{
	strcopy(sWord, sizeof(sWord), Dictionary[GetRandomInt(0, sizeof(Dictionary) - 1)]);
	TrimString(sWord);
	CGOPrintToChatAll("Напиши слово \"{GREEN}%s{DEFAULT}\" и получи {RED}%d{DEFAULT} кредитов", sWord, REW);
	bCanSend = true;
	
	CreateTimer(TIME_TO_ANSWER, TimeToAnswer);
	return Plugin_Continue;
}

public Action TimeToAnswer(Handle hTimer)
{
	bCanSend = false;
	CGOPrintToChatAll("Время вышло, никто не ответил");
	return Plugin_Continue;
}