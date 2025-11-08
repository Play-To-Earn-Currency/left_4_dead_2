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
static char pteEarnOnRoundLose[40] = "100000000000000000";
static char pteShowOnRoundLose[20] = "0.1";
static char pteEarnOnMarker[40]    = "100000000000000000";
static char pteShowOnMarker[20]    = "0.1";
static char pteEarnOnRoundWin[40]  = "300000000000000000";
static char pteShowOnRoundWin[20]  = "0.3";

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

        if (StrContains(commandLine, "-pteVersus 1") == -1)
        {
            PrintToServer("[PTE Versus] Will not be initialized, 'pteVersus' is not '1'");
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

                PrintToServer("[PTE Versus] Config path: %s", configPath);
            }
            else
            {
                configPath = "addons/sourcemod/configs/play_to_earn_versus.cfg";
                PrintToServer("[PTE Versus] No -configPath provided using default %s", configPath);
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

                WriteFileLine(file, "    \"pteEarnOnRoundLose\"       \"str:100000000000000000\"");
                WriteFileLine(file, "");
                WriteFileLine(file, "    \"pteShowOnRoundLose\"       \"0.1\"");
                WriteFileLine(file, "");
                WriteFileLine(file, "    \"pteEarnOnMarker\"       \"str:100000000000000000\"");
                WriteFileLine(file, "");
                WriteFileLine(file, "    \"pteShowOnMarker\"       \"0.1\"");
                WriteFileLine(file, "");
                WriteFileLine(file, "    \"pteEarnOnRoundWin\"       \"str:300000000000000000\"");
                WriteFileLine(file, "");
                WriteFileLine(file, "    \"pteShowOnRoundWin\"       \"0.3\"");

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

            kv.GetString("pteEarnOnRoundLose", pteEarnOnRoundLose, sizeof(pteEarnOnRoundLose), "str:100000000000000000");
            RemoveStrPrefix(pteEarnOnRoundLose, sizeof(pteEarnOnRoundLose));
            kv.GetString("pteShowOnRoundLose", pteShowOnRoundLose, sizeof(pteShowOnRoundLose), "0.1");
            TrimTrailingZeros(pteShowOnRoundLose);
            kv.GetString("pteEarnOnMarker", pteEarnOnMarker, sizeof(pteEarnOnMarker), "str:100000000000000000");
            RemoveStrPrefix(pteEarnOnMarker, sizeof(pteEarnOnMarker));
            kv.GetString("pteShowOnMarker", pteShowOnMarker, sizeof(pteShowOnMarker), "0.1");
            TrimTrailingZeros(pteShowOnMarker);
            kv.GetString("pteEarnOnRoundWin", pteEarnOnRoundWin, sizeof(pteEarnOnRoundWin), "str:300000000000000000");
            RemoveStrPrefix(pteEarnOnRoundWin, sizeof(pteEarnOnRoundWin));
            kv.GetString("pteShowOnRoundWin", pteShowOnRoundWin, sizeof(pteShowOnRoundWin), "0.3");
            TrimTrailingZeros(pteShowOnRoundWin);
        }
    }

    // Survivor progress
    HookEventEx("versus_marker_reached", MarkerReached, EventHookMode_Post);

    // Round start
    HookEventEx("versus_round_start", RoundStart, EventHookMode_Post);

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
public void MarkerReached(Event event, const char[] name, bool dontBroadcast)
{
    int userid   = event.GetInt("userid");
    int marker   = event.GetInt("marker");

    int byClient = GetClientOfUserId(userid);

    PrintToServer("[PTE] Marker Reached");
    if (shouldDebug)
    {
        PrintToServer("[PTE] userid: %d", byClient);
        PrintToServer("[PTE] marker: %d", marker);
    }

    int onlinePlayers[MAXPLAYERS];
    GetOnlinePlayers(onlinePlayers, sizeof(onlinePlayers));

    for (int i = 0; i < MAXPLAYERS; i++)
    {
        int client = onlinePlayers[i];
        if (client == 0) break;

        if (!IsValidClient(client)) continue;
        if (GetClientTeam(client) != 2 || !IsPlayerAlive(client)) continue;

        IncrementWallet(client, pteEarnOnMarker, pteShowOnMarker, " PTE, by progress");
    }
}

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
}

public void RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    int winner = event.GetInt("winner");
    int reason = event.GetInt("reason");

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
        PrintToServer("[PTE] Winner: %d", winner);    // Does not work for some god damn reason
        PrintToServer("[PTE] Reason: %d", reason);
        PrintToServer("[PTE] Message: %s", message);
        PrintToServer("[PTE] Time: %f", time);
    }

    int onlinePlayers[MAXPLAYERS];
    GetOnlinePlayers(onlinePlayers, sizeof(onlinePlayers));

    winner = 3;
    for (int i = 0; i < MAXPLAYERS; i++)
    {
        int client = onlinePlayers[i];
        if (client == 0) break;

        // 2 Survival - 3 Zombie
        int team = GetClientTeam(client);

        if (team == 2)
        {
            // Check if a player survivor is alive
            if (!(GetEntProp(client, Prop_Send, "m_isIncapacitated") != 0) && IsPlayerAlive(client))
            {
                // Yes it is, so we can say that the winner team is survivor
                winner = 2;
                break;
            }
        }
    }

    for (int i = 0; i < MAXPLAYERS; i++)
    {
        int client = onlinePlayers[i];
        if (client == 0) break;

        if (!IsValidClient(client)) continue;

        int team = GetClientTeam(client);
        if (team == winner) IncrementWallet(client, pteEarnOnRoundWin, pteShowOnRoundWin, " PTE , by winning");
        else IncrementWallet(client, pteEarnOnRoundLose, pteShowOnRoundLose, " PTE , by losing");

        if (shouldDebug)
        {
            PrintToServer("[PTE] Player: %d, team: %d", client, team);
        }
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