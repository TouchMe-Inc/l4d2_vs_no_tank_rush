#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>
#include <colors>


public Plugin myinfo = {
	name = "NoTankRush",
	author = "Jahze, TouchMe",
	version = "build0000",
	description = "Stops distance points accumulating whilst the tank is alive, with the option of unfreezing distance on reaching the Saferoom",
	url = "https://github.com/TouchMe-Inc/l4d2_vs_no_tank_rush"
};


#define TEAM_INFECTED           3

#define CLASS_TANK              8

#define IsTankInPlay            L4D2_IsTankInPlay
#define SetVersusMaxScore       L4D_SetVersusMaxCompletionScore
#define GetVersusMaxScore       L4D_GetVersusMaxCompletionScore


bool g_bIsPointsFrozen = false;

int g_iMaxCompletionScore = 0;

ConVar
	g_cvDefrostSaferoom = null,
	g_cvDefrostForBot = null
;


/**
 * Called before OnPluginStart.
 *
 * @param myself            Handle to the plugin.
 * @param late              Whether or not the plugin was loaded "late" (after map load).
 * @param error             Error message buffer in case load failed.
 * @param err_max           Maximum number of characters for error message buffer.
 * @return                  APLRes_Success | APLRes_SilentFailure.
 */
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("vs_no_tank_rush.phrases");

	// ConVars.
	g_cvDefrostSaferoom = CreateConVar("sm_ntr_defrost_saferoom", "1", "Unfreezes points if players have reached the saferoom", _, true, 0.0, true, 1.0);
	g_cvDefrostForBot = CreateConVar("sm_ntr_defrost_for_bot", "1", "Unfreezes points if the tank has become a bot", _, true, 0.0, true, 1.0);

	// Events.
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("tank_spawn", Event_TankSpawn, EventHookMode_PostNoCopy);
	HookEvent("player_death", Event_TankDeath, EventHookMode_Post);
	HookEvent("player_bot_replace", Event_TankReplaceBot);

}

public void OnMapStart() {
	g_bIsPointsFrozen = false;
}

public Action L4D2_OnEndVersusModeRound(bool bHasSurvivor)
{
	if (!IsPointsFrozen() || !bHasSurvivor || !GetConVarBool(g_cvDefrostSaferoom) || !IsTankInPlay()) {
		return Plugin_Continue;
	}

	DefrostPoints();
	CPrintToChatAll("%t%t", "TAG", "DEFROST_SAFEROOM");

	return Plugin_Continue;
}

void Event_RoundStart(Event event, const char[] sEventName, bool bDontBroadcast)
{
	if (InSecondHalfOfRound()) {
		DefrostPoints();
	}
}

void Event_TankSpawn(Event event, const char[] sEventName, bool bDontBroadcast)
{
	if (!IsPointsFrozen())
	{
		FreezePoints();
		CPrintToChatAll("%t%t", "TAG", "FREEZE_POINTS");
	}
}

void Event_TankDeath(Event event, const char[] sEventName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(event, "userid"));

	if (!iClient || !IsClientInfected(iClient) || !IsClientTank(iClient)) {
		return;
	}

	CreateTimer(1.0, Timer_CheckAliveTank, .flags = TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_CheckAliveTank(Handle timer)
{
	if (!IsTankInPlay())
	{
		DefrostPoints();
		CPrintToChatAll("%t%t", "TAG", "DEFROST_POINTS");
	}

	return Plugin_Stop;
}

void Event_TankReplaceBot(Event event, const char[] sEventName, bool bDontBroadcast)
{
	if (!GetConVarBool(g_cvDefrostForBot)) {
		return;
	}

	int iTank = GetClientOfUserId(GetEventInt(event, "bot"));

	if (!IsClientInfected(iTank) || !IsClientTank(iTank) || HasPlayerTank()) {
		return;
	}

	DefrostPoints();
}

void FreezePoints()
{
	if (!IsPointsFrozen())
	{
		g_iMaxCompletionScore = GetVersusMaxScore();
		g_bIsPointsFrozen = true;

		SetVersusMaxScore(0);
	}
}

void DefrostPoints()
{
	if (IsPointsFrozen())
	{
		g_bIsPointsFrozen = false;

		SetVersusMaxScore(g_iMaxCompletionScore);
	}
}

bool IsPointsFrozen() {
	return g_bIsPointsFrozen;
}

/**
 * Checks if the current round is the second.
 *
 * @return                  Returns true if is second round, otherwise false.
 */
bool InSecondHalfOfRound() {
	return view_as<bool>(GameRules_GetProp("m_bInSecondHalfOfRound"));
}

/**
 * Infected team player?
 */
bool IsClientInfected(int iClient) {
	return (GetClientTeam(iClient) == TEAM_INFECTED);
}

/**
 * Get the zombie player class.
 */
int GetClientClass(int iClient) {
	return GetEntProp(iClient, Prop_Send, "m_zombieClass");
}

bool IsClientTank(int iClient) {
	return (GetClientClass(iClient) == CLASS_TANK);
}

bool HasPlayerTank()
{
	for (int iClient = 1; iClient <= MaxClients; iClient ++)
	{
		if (!IsClientInGame(iClient) || IsFakeClient(iClient)
		|| !IsClientInfected(iClient) || !IsClientTank(iClient)) {
			continue;
		}

		return true;
	}

	return false;
}
