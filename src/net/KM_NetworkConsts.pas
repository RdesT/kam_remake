unit KM_NetworkConsts;
{$I KaM_Remake.inc}
interface
uses
  KM_NetworkTypes;


const
  NET_MP_GAME_STATE: array [TKMNetGameState] of TMPGameState = (mgsNone, mgsNone, mgsNone, mgsLobby, mgsLoading, mgsGame, mgsGame);
  NET_ALLOWED_PACKETS_SET: array [TKMNetGameState] of set of TKMNetMessageKind = (
    //lgsNone
    [],
    //lgsConnecting
    [mkRefuseToJoin,mkIndexOnServer,mkNetProtocolVersion,mkWelcomeMessage,mkPing,
     mkConnectedToRoom,mkPingFpsInfo,mkKicked,mkServerName,mkReqPassword],
    //lgsQuery
    [mkAllowToJoin,mkRefuseToJoin,mkAuthChallenge,mkPing,mkPingFpsInfo,mkKicked],
    //lgsLobby
    [mkAskForAuth,mkAskToJoin,mkClientLost,mkReassignHost,mkDisconnect,mkPing,mkPingFpsInfo,mkPlayersList,
     mkRequestStartingLoc,mkRequestTeam,mkRequestFlagColor,mkResetMap,mkMapSelect,mkSaveSelect,
     mkReadyToStart,mkStart,mkTextChat,mkKicked,mkLangCode,mkGameOptions,mkServerName,
     mkFileRequest,mkFileSendStarted,mkFileChunk,mkFileEnd,mkFileAck,mkFileProgress,
     mkTextTranslated,mkHasMapOrSave,mkSetPassword],
    //lgsLoading
    [mkAskForAuth,mkClientLost,mkReassignHost,mkDisconnect,mkPing,mkPingFpsInfo,mkPlayersList,
     mkReadyToPlay,mkPlay,mkTextChat,mkKicked,mkTextTranslated,mkVote],
    //lgsGame
    [mkAskForAuth,mkClientLost,mkReassignHost,mkDisconnect,mkPing,mkPingFpsInfo,{mkFPS,}mkPlayersList,mkReadyToReturnToLobby,
     mkCommands,mkTextChat,mkResyncFromTick,mkAskToReconnect,mkKicked,mkClientReconnected,mkTextTranslated,mkVote,
     mkAskToSendCrashreport],
    //lgsReconnecting
    [mkIndexOnServer,mkNetProtocolVersion,mkWelcomeMessage,mkPing,{mkFPS,}mkConnectedToRoom,
     mkPingFpsInfo,mkPlayersList,mkReconnectionAccepted,mkRefuseReconnect,mkKicked]
  );

  JOIN_TIMEOUT = 8000; //8 sec. Timeout for join queries
  RECONNECT_PAUSE = 3000; //Time in ms which we wait before attempting to reconnect (stops the socket from becoming overloaded)
  VOTE_TIMEOUT = 60000; //60 sec. Timeout for votes

implementation

end.

