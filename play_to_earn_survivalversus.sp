#include <sourcemod>
#include <play_to_earn_database>

public Plugin myinfo =
{
    name        = "Play To Earn",
    author      = "Gxsper",
    description = "Play to Earn for Left 4 Dead 2 Versus",
    version     = "1.0",
    url         = "https://github.com/Play-To-Earn-Currency/left_4_dead_2"
};

// Configurations
static char pteEarnOnSurvivalTimestamp[40] = "200000000000000000";
static char pteShowOnSurvivalTimestamp[20] = "0.2";
static char pteEarnOnInfectedTimestamp[40] = "100000000000000000";
static char pteShowOnInfectedTimestamp[20] = "0.1";

int         timeStampSurvived;
Handle      timeStampSurvivedTimer = INVALID_HANDLE;

bool        shouldDebug            = false;

public void OnPluginStart()
{
    char commandLine[512];
    char configPath[PLATFORM_MAX_PATH];
    if (GetCommandLine(commandLine, sizeof(commandLine)))
    {
        if (StrContains(commandLine, "-debug") != -1)
        {
            PrintToServer("[PTE] Debug is enabled");
            shouldDebug = true;
        }

        if (StrContains(commandLine, "-pteSurvivalVersus 1") == -1)
        {
            PrintToServer("[PTE Default] Will not be initialized, 'pteSurvivalVersus' is not '1'");
            return;
        }

        // Get config path
        {
            int start = StrContains(commandLine, "-configPath ");
            if (start != -1)
            {
                start += strlen("-configPath ");

                int end = start;
                while (commandLine[end] != '\0' && commandLine[end] != ' ')
                {
                    end++;
                }

                int length = end - start;
                strcopy(configPath, sizeof(configPath), commandLine[start]);
                configPath[length] = '\0';

                PrintToServer("[PTE Default] Config path: %s", configPath);
            }
            else
            {
                configPath = "addons/sourcemod/configs/play_to_earn_survivalversus.cfg";
                PrintToServer("[PTE Default] No -configPath provided using default %s", configPath);
            }
        }
    }

    // Configuration Load
    {
        if (!FileExists(configPath))
        {
            Handle file = OpenFile(configPath, "w");
            if (file != null)
            {
                WriteFileLine(file, "\"PlayToEarn\"");
                WriteFileLine(file, "{");

                WriteFileLine(file, "    \"pteEarnOnSurvivalTimestamp\"       \"str:200000000000000000\"");
                WriteFileLine(file, "");
                WriteFileLine(file, "    \"pteShowOnSurvivalTimestamp\"       \"0.2\"");
                WriteFileLine(file, "");
                WriteFileLine(file, "    \"pteEarnOnInfectedTimestamp\"       \"str:100000000000000000\"");
                WriteFileLine(file, "");
                WriteFileLine(file, "    \"pteShowOnInfectedTimestamp\"       \"0.1\"");

                WriteFileLine(file, "}");
                CloseHandle(file);
                PrintToServer("[PTE] Configuration file created: %s", configPath);
            }
            else
            {
                PrintToServer("[PTE] Cannot create default file.");
                return;
            }
        }

        KeyValues kv = new KeyValues("PlayToEarn");
        if (!kv.ImportFromFile(configPath))
        {
            delete kv;
            PrintToServer("[PTE] Cannot load configuration file: %s", configPath);
        }
        // Loading from file
        else {
            // Yes, str: prefix is totally necessary because for some UNKOWN reasons it try to convert to int32 and overflow to int32 max

            kv.GetString("pteEarnOnSurvivalTimestamp", pteEarnOnSurvivalTimestamp, sizeof(pteEarnOnSurvivalTimestamp), "str:100000000000000000");
            RemoveStrPrefix(pteEarnOnSurvivalTimestamp, sizeof(pteEarnOnSurvivalTimestamp));
            kv.GetString("pteShowOnSurvivalTimestamp", pteShowOnSurvivalTimestamp, sizeof(pteShowOnSurvivalTimestamp), "0.1");
            TrimTrailingZeros(pteShowOnSurvivalTimestamp);
        }
    }

    // Round start
    HookEventEx("survival_round_start", RoundStart, EventHookMode_Post);

    // Round ended
    HookEventEx("round_end", RoundEnd, EventHookMode_Post);

    // Player team changed
    HookEventEx("player_team", OnPlayerChangeTeam, EventHookMode_Post);

    // Wallet command
    RegConsoleCmd("wallet", CommandRegisterWallet, "Set up your Wallet address");

    // ID command
    RegConsoleCmd("id", CommandViewSteamId, "View your steam id");

    // Menu command
    RegConsoleCmd("menu", CommandOpenMenu, "Open PTE menu");

    PrintToServer("[PTE] Play to Earn plugin has been initialized");
}

//
// EVENTS
//
public void RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    PrintToServer("[PTE] Round start");

    int onlinePlayers[MAXPLAYERS];
    GetOnlinePlayers(onlinePlayers, sizeof(onlinePlayers));

    for (int i = 0; i < MAXPLAYERS; i++)
    {
        int client = onlinePlayers[i];
        if (client == 0) break;

        if (!IsValidClient(client)) continue;

        RegisterPlayer(client);
    }

    timeStampSurvived      = 0;
    timeStampSurvivedTimer = CreateTimer(1.0, OnTimestampPassed, 0, TIMER_REPEAT);
}

public Action OnTimestampPassed(Handle timer, any data)
{
    timeStampSurvived++;

    if (timeStampSurvived % 60 == 0)
    {
        int onlinePlayers[MAXPLAYERS];
        GetOnlinePlayers(onlinePlayers, sizeof(onlinePlayers));

        for (int i = 0; i < MAXPLAYERS; i++)
        {
            int client = onlinePlayers[i];
            if (client == 0) break;

            if (GetClientTeam(client) == 2)
                IncrementWallet(client, pteEarnOnSurvivalTimestamp, pteShowOnSurvivalTimestamp, " PTE, for playing");
            else if (GetClientTeam(client) == 3)
                IncrementWallet(client, pteEarnOnInfectedTimestamp, pteShowOnInfectedTimestamp, " PTE, for playing");
        }
    }

    return Plugin_Handled;
}

public void RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    if (timeStampSurvivedTimer != INVALID_HANDLE)
        CloseHandle(timeStampSurvivedTimer);
    timeStampSurvivedTimer = INVALID_HANDLE;

    int reason             = event.GetInt("reason");

    // Restart from hibernation
    if (reason == 8)
    {
        PrintToServer("[PTE] Round ended ignored, reason: restart from hibernation");
        return;
    }

    // Scenario Restart
    if (reason == 0)
    {
        PrintToServer("[PTE] Round ended ignored, reason: scenario restart");
        return;
    }

    // Chapter ended
    if (reason == 6)
    {
        PrintToServer("[PTE] Round ended ignored, reason: chapter ended");
        return;
    }

    char message[128];
    event.GetString("message", message, sizeof(message));
    float time = event.GetFloat("time");

    PrintToServer("[PTE] Round ended");
    if (shouldDebug)
    {
        PrintToServer("[PTE] Reason: %d", reason);
        PrintToServer("[PTE] Message: %s", message);
        PrintToServer("[PTE] Time: %s", time);
    }
}

public void OnPlayerChangeTeam(Event event, const char[] name, bool dontBroadcast)
{
    bool disconnected = event.GetBool("disconnect");
    if (disconnected) return;

    int userid  = event.GetInt("userid");
    int team    = event.GetInt("team");
    int oldTeam = event.GetInt("oldteam");

    int client  = GetClientOfUserId(userid);
    if (!IsValidClient(client))
    {
        if (shouldDebug)
            PrintToServer("[PTE] Fake client %d, ignoring team change", userid);
        return;
    }

    if (shouldDebug)
        PrintToServer("[PTE] %d changed their team: %d, previously: %d", client, team, oldTeam);

    if (oldTeam == 0)
    {
        PrintToServer("[PTE] Player started playing %d", client);

        RegisterPlayer(client);
        ShowMenu(client);
    }
}
//
//
//

//
// Commands
//
public Action CommandRegisterWallet(int client, int args)
{
    if (args < 1)
    {
        PrintToChat(client, "[PTE] You can set your wallet using !wallet 0x123");
        return Plugin_Handled;
    }

    char walletAddress[256];
    GetCmdArgString(walletAddress, sizeof(walletAddress));

    UpdateWallet(client, walletAddress);

    return Plugin_Handled;
}

public Action CommandViewSteamId(int client, int args)
{
    PrintToChat(client, "[PTE] Your steam id is: %d", GetSteamAccountID(client));

    return Plugin_Handled;
}

public Action CommandOpenMenu(int client, int args)
{
    ShowMenu(client);

    return Plugin_Handled;
}

void RemoveStrPrefix(char[] str, int maxlen)
{
    char PREFIX[]  = "str:";
    int  prefixLen = sizeof(PREFIX) - 1;

    if (StrContains(str, PREFIX) == 0)
    {
        strcopy(str, maxlen, str[prefixLen]);
    }
}
//
//
//