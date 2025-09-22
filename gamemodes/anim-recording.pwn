#include <open.mp>
#include <websockets>
#include <requests>
#include <exec>
#include <zcmd>
#include <sscanf2>

#include "animlist.inc"

#define OBS_WEBSOCKET_ENDPOINT "ws://127.0.0.1:4455"
#define MAX_WS_CONNECTION_ATTEMPTS 5
#define VIDEO_SAVE_PATH "C:\\Users\\Leamir\\Videos\\samp-animations" // Videos will be moved here, in each category folder - This folder must already exist in disk

new ws_client:obsWebSocket;

new currentAnimIndex = -1, actorId = INVALID_ACTOR_ID, currentTimer = -1, bool:isPlayingAnim;

main()
{
	print("----------------------------------");
	print("  Anim recording Script\n");
	print("----------------------------------");
}

public OnPlayerConnect(playerid)
{
    if (actorId == INVALID_ACTOR_ID)
        actorId = CreateActor(0, 2325.6008, 1467.4624, 42.8203, 0.0);

	GameTextForPlayer(playerid,"~w~SA-MP: ~r~Bare Script",5000,5);

    PreloadAnimLibs(playerid);
	return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    KillTimer(currentTimer);
    ClearActorAnimations(actorId);


    return 1;
}

#define PRESSED(%0) \
	(((newkeys & (%0)) == (%0)) && ((oldkeys & (%0)) != (%0)))

new lastExecution = 0;
public OnPlayerUpdate(playerid)
{
    if (!isPlayingAnim)
        return 1;

    if (lastExecution + 75 > GetTickCount())
        return 1;

    new KEY:keys, updown, leftright;
    GetPlayerKeys(playerid, keys, updown, leftright);
    if (leftright == KEY_LEFT) // Left arrow
    {
        currentAnimIndex--;
        if (currentAnimIndex < 0)
            currentAnimIndex = 0;

        KillTimer(currentTimer);
        ClearActorAnimations(actorId);
        SendOBSRequest("StopRecord", .requestId = "no-save");
        currentTimer = SetTimerEx("PlayNextAnimation", 100, false, "dd", playerid, 1);
    }
    else if (leftright == KEY_RIGHT) // Right arrow
    {
        currentAnimIndex++;
        if (currentAnimIndex >= sizeof(animList))
            currentAnimIndex = sizeof(animList) - 1;

        KillTimer(currentTimer);
        ClearActorAnimations(actorId);
        SendOBSRequest("StopRecord", .requestId = "no-save");
        currentTimer = SetTimerEx("PlayNextAnimation", 100, false, "dd", playerid, 1);
    }
    return 1;
}

public OnPlayerKeyStateChange(playerid, KEY:newkeys, KEY:oldkeys)
{
    if (PRESSED(KEY_SPRINT)) // Space
    {
        if (isPlayingAnim)
        {
            isPlayingAnim = false;
            ClearActorAnimations(actorId);
            KillTimer(currentTimer);
            OnAllAnimationsRecordingFinished(playerid);
            SendOBSRequest("StopRecord", .requestId = "no-save");
        }
    }
    return 1;
}

public OnPlayerCommandText(playerid, cmdtext[])
{

	return 0;
}

public OnPlayerSpawn(playerid)
{
    SendClientMessage(playerid, 0xFFFFFFFF, "Use {00FF00}/recordanims{FFFFFF} to start recording animations.");
    SendClientMessage(playerid, 0xFFFFFFFF, "Use {FFFF00}SPACE{FFFFFF} to stop recording and return to normal.");
    SendClientMessage(playerid, 0xFFFFFFFF, "Use {FFFF00}LEFT/RIGHT ARROW{FFFFFF} to skip to previous/next animation.");
    SendClientMessage(playerid, 0xFFFFFFFF, "Use {00FF00}/testanim{FFFFFF} to test a specific animation. without recording");
	SetPlayerInterior(playerid,0);
	TogglePlayerClock(playerid,false);
	return 1;
}

public OnPlayerDeath(playerid, killerid, WEAPON:reason)
{
   	return 1;
}

SetupPlayerForClassSelection(playerid)
{
 	SetPlayerInterior(playerid,14);
	SetPlayerPos(playerid,258.4893,-41.4008,1002.0234);
	SetPlayerFacingAngle(playerid, 270.0);
	SetPlayerCameraPos(playerid,256.0815,-43.0475,1004.0234);
	SetPlayerCameraLookAt(playerid,258.4893,-41.4008,1002.0234);
}

public OnPlayerRequestClass(playerid, classid)
{
	SetupPlayerForClassSelection(playerid);
	return 1;
}

public OnGameModeInit()
{
	SetGameModeText("Anim recording Script");
	ShowPlayerMarkers(PLAYER_MARKERS_MODE_GLOBAL);
	ShowNameTags(true);
	AllowAdminTeleport(true);

	AddPlayerClass(265,1958.3783,1343.1572,15.3746,270.1425);

    printf("Connecting to OBS WebSocket at %s", OBS_WEBSOCKET_ENDPOINT);
    obsWebSocket = CreateWSClient("OnWebSocketConnect", "OnWebSocketFail", "OnWebSocketDisconnect", "OnWebSocketMessage");
    WSClientConnect(obsWebSocket, OBS_WEBSOCKET_ENDPOINT);

	return 1;
}

static connectionAttempts = 0;

forward OnWebSocketFail(ws_client:ws);
public OnWebSocketFail(ws_client:ws)
{
    printf("WebSocket connection failed.");
    connectionAttempts++;
    if (connectionAttempts < MAX_WS_CONNECTION_ATTEMPTS)
    {
        printf("Retrying connection... (Attempt %d of %d)", connectionAttempts + 1, MAX_WS_CONNECTION_ATTEMPTS);
        WSClientConnect(obsWebSocket, OBS_WEBSOCKET_ENDPOINT);
        return 1;
    }
 
    print("Max connection attempts reached. Exiting script.");
    SendRconCommand("exit");
    return 1;
}

forward OnWebSocketDisconnect(ws_client:ws);
public OnWebSocketDisconnect(ws_client:ws)
{
    printf("WebSocket disconnected.");
    SendRconCommand("exit");
    return 1;
}

HandleHelloMessage(Node:response)
{
    /*
    {
        "obsStudioVersion": string,
        "obsWebSocketVersion": string,
        "rpcVersion": number,
        "authentication":(optional) {
            "challenge": "+IxH4CnCiqpX1rM9scsNynZzbOe4KhDeYcTNS3PDaeY=",
            "salt": "lM1GncleQOaCu9lT1yeUZhFYnqhsLLP1G5lAGo3ixaI="
        }
    }
    */
    new rpcVersion;
    JsonGetInt(response, "rpcVersion", rpcVersion);

    new Node:authenticationData;
    JsonGetObject(response, "authentication", authenticationData);

    // printf("RPC Version: %d", rpcVersion);

    new obsAuthenticationChallenge[128], obsAuthenticationSalt[128];
    JsonGetString(authenticationData, "challenge", obsAuthenticationChallenge);
    JsonGetString(authenticationData, "salt", obsAuthenticationSalt);

    /*
    identify:
    {
        "rpcVersion": number,
        "authentication": string(optional),
        "eventSubscriptions": number(optional) = (EventSubscription::All)
    }
    */
    if (obsAuthenticationChallenge[0] == EOS)
    {
        // print("No authentication required. Sending Identify message.");

        SendOBSMessage(1, JsonObject(
            "rpcVersion", JsonInt(rpcVersion),
            "eventSubscriptions", JsonInt(0) // Subscribe to nothing
        ));
    }
    else
    {
        print("[FATAL] Authentication required, but not implemented in this script. I'm not doing it.");
        print("[FATAL] Disable authentication in OBS for this script to work.");
        SendRconCommand("exit");
    }

    return 1;
}

HandleEventMessage(Node:response)
{
    return 1;
}

HandleRequestResponse(Node:response)
{
    new Node:responseData, outputPath[256], requestId[64], requestType[64];
    JsonGetString(response, "requestType", requestType);

    /*
    new tmp[256];
    JsonStringify(response, tmp);
    printf("RequestResponse: %s", tmp);
    */

    if (strcmp(requestType, "StopRecord", true) != 0)
        return 1; // We only care about StopRecord responses

    JsonGetString(response, "requestId", requestId);
    if (strcmp(requestId, "no-save", true) == 0)
        return 1;


    JsonGetObject(response, "responseData", responseData);
    JsonGetString(responseData, "outputPath", outputPath);
    for (new i; i < sizeof(requestId); i++)
    {
        if (requestId[i] == '-')
        {
            requestId[i] = '\\';
            break;
        }
    }

    new command[1024];
    for (new i; i < sizeof(outputPath); i++)
    {
        if (outputPath[i] == '/')
            outputPath[i] = '\\';
    }
    format(command, sizeof(command), "move \"%s\" \"%s\\%s.mp4\" >nul 2>&1", outputPath, VIDEO_SAVE_PATH, requestId);
    SetTimerEx("fwExec", 350, false, "s", command);
    return 1;
}

forward fwExec(command[]);
public fwExec(command[])
{
    exec(command);
    return 1;
}

forward OnWebSocketMessage(ws_client:ws, message[]);
public OnWebSocketMessage(ws_client:ws, message[])
{
    new Node:data, opcode, Node:response;
    JsonParse(message, data);

    JsonGetInt(data, "op", opcode);
    JsonGetObject(data, "d", response);

    switch (opcode)
    {
        case 0: // Hello
        {
            HandleHelloMessage(response);
            return 1;
        }
        // (Re)Identified can be safely ignored
        case 2: // Identified
        {
            OnOBSReady();
            return 1;
        }
        case 3: // Reidentified
        {
            return 1;
        }
        case 5: // Event
        {
            HandleEventMessage(response);
            return 1;
        }
        case 7: // RequestResponse
        {
            HandleRequestResponse(response);
            return 1;
        }
    }
    return 1;
}

forward OnWebSocketConnect(ws_client:ws);
public OnWebSocketConnect(ws_client:ws)
{
    printf("WebSocket connected.");
    return 1;
}

SendOBSMessage(opcode, Node:payload)
{
    new Node:SendData = JsonObject(
        "op", JsonInt(opcode), // Identify opcode
        "d", payload
    );
    new SendMessage[512];
    JsonStringify(SendData, SendMessage);
    WSClientSend(obsWebSocket, SendMessage);
}

SendOBSRequest(const requestType[], Node:requestData = Node:-1, const requestId[] = "undefined")
{
    /*
    "requestType": "...",
    "requestId": "...",
    "requestData": {
        ...
    }
    */

    if (requestData != Node:-1)
    {
        SendOBSMessage(6, JsonObject(
            "requestType", JsonString(requestType),
            "requestId", JsonString(requestId),
            "requestData", requestData
        ));
    }
    else
    {
        SendOBSMessage(6, JsonObject(
            "requestType", JsonString(requestType),
            "requestId", JsonString(requestId) // Static request ID, because I don't care about responses
        ));
    }
}

forward OnOBSReady();
public OnOBSReady()
{

    SendClientMessageToAll(0x00FF00, "OBS WebSocket is ready to use.");
    print("OBS WebSocket is ready to use.");

    return 1;
}

CMD:recordanims(playerid, const params[])
{
    new currentAnimLib[32], currentAnimName[32];
    if (sscanf(params, "s[32]s[32]", currentAnimLib, currentAnimName))
    {
        currentAnimIndex = 0;
    }
    else
    {
        if (currentAnimLib[0] == EOS)
        {
            SendClientMessage(playerid, 0xFF0000, "Animation not found. Usage: /recordanims [AnimLib] [AnimName]");
            SendClientMessage(playerid, 0x00FF00, "Animation lib and name are optional. If not provided, the first animation in the list will be used.");
            return 1;
        }

        currentAnimIndex = -1;
        for (new i; i < sizeof(animList); i++)
        {
            if (strcmp(currentAnimLib, animList[i][animLib], true) == 0 && strcmp(currentAnimName, animList[i][animName], true) == 0)
            {
                currentAnimIndex = i;
                break;
            }
        }
    
        if (currentAnimIndex == -1)
        {
            SendClientMessage(playerid, 0xFF0000, "Animation not found. Usage: /recordanims [AnimLib] [AnimName]");
            SendClientMessage(playerid, 0x00FF00, "Animation lib and name are optional. If not provided, the first animation in the list will be used.");
            return 1;
        }
    }
    TogglePlayerSpectating(playerid, true);

    currentTimer = SetTimerEx("ResumeAnimationRecordings", 500, false, "d", playerid);
    isPlayingAnim = true;

    return 1;
}

forward ResumeAnimationRecordings(playerid);
public ResumeAnimationRecordings(playerid)
{
    if (actorId == INVALID_ACTOR_ID)
    {
        actorId = CreateActor(0, 2325.6008, 1467.4624, 42.8203, 0.0);
    }

    SetPlayerCameraLookAt(playerid, 2325.6008, 1467.4624, 42.8203);
    SetPlayerCameraPos(playerid, 2325.6008, 1472.4624, 44.3203);

    for (new i; i < 30; i++) // Clear chat
        SendClientMessage(playerid, 0xFFFFFF, "");

    currentTimer = SetTimerEx("PlayNextAnimation", 5000, false, "dd", playerid, 1);
    return 1;
}

forward PlayNextAnimation(playerid, justStarted);
public PlayNextAnimation(playerid, justStarted)
{
    new str[256];
    if (justStarted == 1)
    {
        SendOBSRequest("StopRecord", .requestId = "no-save");
    }
    else
    {
        format(str, sizeof(str), "%s-%s", animList[currentAnimIndex-1][animLib], animList[currentAnimIndex-1][animName]);
        SendOBSRequest("StopRecord", .requestId = str); // Sent with ID for saving correctly
    }

    if (currentAnimIndex >= sizeof(animList))
    {
        isPlayingAnim = false;
        ClearActorAnimations(actorId);
        KillTimer(currentTimer);
        OnAllAnimationsRecordingFinished(playerid);
        return 1;
    }
    SendClientMessage(playerid, 0x00FF00FF, "%04d/%04d", currentAnimIndex+1, sizeof(animList));

    format(str, sizeof(str), "mkdir \"%s\\%s\" >nul 2>&1", VIDEO_SAVE_PATH, animList[currentAnimIndex][animLib]);
    exec(str);

    ClearActorAnimations(actorId);

    currentTimer = SetTimerEx("PlayNextAnimation2", 500, false, "d", playerid);
    return 1;
}

forward PlayNextAnimation2(playerid);
public PlayNextAnimation2(playerid)
{
    SendOBSRequest("StartRecord");

    // ApplyActorAnimation(actorId, animList[currentAnimIndex][animLib], animList[currentAnimIndex][animName], 4.1, true, false, false, false, 0);
    SetTimerEx("fwApplyActorAnimation", 250, false, "dssfddddd", actorId, animList[currentAnimIndex][animLib], animList[currentAnimIndex][animName], 4.1, 0, 0, 0, 0, 0);

    currentTimer = SetTimerEx("PlayNextAnimation", floatround((animList[currentAnimIndex][animDuration]+0.25) * 1000, floatround_ceil), false, "dd", playerid, 0);

    currentAnimIndex++;
    
    return 1;
}

forward fwApplyActorAnimation(actorid, const animationLibrary[], const animationName[], Float:delta, loop, lockX, lockY, freeze, time);
public fwApplyActorAnimation(actorid, const animationLibrary[], const animationName[], Float:delta, loop, lockX, lockY, freeze, time)
{
    return ApplyActorAnimation(actorid, animationLibrary, animationName, delta, loop == 1, lockX == 1, lockY == 1, freeze == 1, time);
}

forward OnAllAnimationsRecordingFinished(playerid);
public OnAllAnimationsRecordingFinished(playerid)
{
    SendClientMessage(playerid, 0x00FF00FF, "All animations recorded.");
    isPlayingAnim = false;

    SetCameraBehindPlayer(playerid);
    TogglePlayerSpectating(playerid, false);

    return 1;
}

CMD:testanim(playerid, const params[])
{
    new toUseAnimLib[32], toUseAnimName[32];
    if (sscanf(params, "s[32]s[32]", toUseAnimLib, toUseAnimName))
    {
        SendClientMessage(playerid, 0xFF0000, "Usage: /testanim [AnimLib] [AnimName]");
        return 1;
    }

    new tempIndex = -1;
    for (new i; i < sizeof(animList); i++)
    {
        if (strcmp(toUseAnimLib, animList[i][animLib], true) == 0 && strcmp(toUseAnimName, animList[i][animName], true) == 0)
        {
            tempIndex = i;
            break;
        }
    }

    if (tempIndex == -1)
    {
        SendClientMessage(playerid, 0xFF0000, "Animation not found. Usage: /testanim [AnimLib] [AnimName]");
        return 1;
    }

    TogglePlayerSpectating(playerid, true);

    currentTimer = SetTimerEx("testAnimStep", 100, false, "ddssd", playerid, 1, toUseAnimLib, toUseAnimName, tempIndex);
    isPlayingAnim = true;

    return 1;
}

forward testAnimStep(playerid, step, const toUseAnimLib[], const toUseAnimName[], tempIndex);
public testAnimStep(playerid, step, const toUseAnimLib[], const toUseAnimName[], tempIndex)
{
    if (step == 1)
    {
        SetPlayerCameraPos(playerid, 2325.6008, 1472.4624, 44.3203);
        SetPlayerCameraLookAt(playerid, 2325.6008, 1467.4624, 42.8203);
        
        currentTimer = SetTimerEx("testAnimStep", 500, false, "ddssd", playerid, 2, toUseAnimLib, toUseAnimName, tempIndex);
    }
    else if (step == 2)
    {
        ApplyActorAnimation(actorId, toUseAnimLib, toUseAnimName, 4.1, true, false, false, false, 0);
        SetTimerEx("fwApplyActorAnimation", 100, false, "dssfddddd", actorId, toUseAnimLib, toUseAnimName, 4.1, 0, 0, 0, 0, 0);

        currentTimer = SetTimerEx("OnAllAnimationsRecordingFinished", floatround((animList[tempIndex][animDuration]+0.5) * 1000, floatround_ceil), false, "dd", playerid, 1);
    }

    return 1;
}

new const AnimLibs[][] = {
  "AIRPORT",      "ATTRACTORS",   "BAR",          "BASEBALL",     "BD_FIRE",
  "BEACH",        "BENCHPRESS",   "BF_INJECTION", "BIKE_DBZ",     "BIKED",
  "BIKEH",        "BIKELEAP",     "BIKES",        "BIKEV",        "BLOWJOBZ",
  "BMX",          "BOMBER",       "BOX",          "BSKTBALL",     "BUDDY",
  "BUS",          "CAMERA",       "CAR",          "CAR_CHAT",     "CARRY",
  "CASINO",       "CHAINSAW",     "CHOPPA",       "CLOTHES",      "COACH",
  "COLT45",       "COP_AMBIENT",  "COP_DVBYZ",    "CRACK",        "CRIB",
  "DAM_JUMP",     "DANCING",      "DEALER",       "DILDO",        "DODGE",
  "DOZER",        "DRIVEBYS",     "FAT",          "FIGHT_B",      "FIGHT_C",
  "FIGHT_D",      "FIGHT_E",      "FINALE",       "FINALE2",      "FLAME",
  "FLOWERS",      "FOOD",         "FREEWEIGHTS",  "GANGS",        "GFUNK",
  "GHANDS",       "GHETTO_DB",    "GOGGLES",      "GRAFFITI",     "GRAVEYARD",
  "GRENADE",      "GYMNASIUM",    "HAIRCUTS",     "HEIST9",       "INT_HOUSE",
  "INT_OFFICE",   "INT_SHOP",     "JST_BUISNESS", "KART",         "KISSING",
  "KNIFE",        "LAPDAN1",      "LAPDAN2",      "LAPDAN3",      "LOWRIDER",
  "MD_CHASE",     "MD_END",       "MEDIC",        "MISC",         "MTB",
  "MUSCULAR",     "NEVADA",       "ON_LOOKERS",   "OTB",          "PARACHUTE",
  "PARK",         "PAULNMAC",     "PED",          "PLAYER_DVBYS", "PLAYIDLES",
  "POLICE",       "POOL",         "POOR",         "PYTHON",       "QUAD",
  "QUAD_DBZ",     "RAPPING",      "RIFLE",        "RIOT",         "ROB_BANK",
  "ROCKET",       "RUNNINGMAN",   "RUSTLER",      "RYDER",        "SCRATCHING",
  "SEX",          "SHAMAL",       "SHOP",         "SHOTGUN",      "SILENCED",
  "SKATE",        "SMOKING",      "SNIPER",       "SNM",          "SPRAYCAN",
  "STRIP",        "SUNBATHE",     "SWAT",         "SWEET",        "SWIM",
  "SWORD",        "TANK",         "TATTOOS",      "TEC",          "TRAIN",
  "TRUCK",        "UZI",          "VAN",          "VENDING",      "VORTEX",
  "WAYFARER",     "WEAPONS",      "WOP",          "WUZI"
};

stock PreloadAnimLibs(playerid) {
  for(new i = 0; i < sizeof(AnimLibs); i++) {
      ApplyAnimation(playerid, AnimLibs[i], "null", 4.0, false, false, false, false, false, t_FORCE_SYNC:1);
  }
  return 1;
}