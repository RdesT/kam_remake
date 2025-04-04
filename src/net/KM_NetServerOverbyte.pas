unit KM_NetServerOverbyte;
{$I KaM_Remake.inc}
interface
uses
  Classes, SysUtils, OverbyteIcsWSocket, OverbyteIcsWSocketS, WinSock;


{ This unit knows nothing about KaM, it's just a puppet in hands of KM_ServerControl,
doing all the low level work on TCP. So we can replace this unit with other TCP Client
without KaM even noticing. }

type
  THandleEvent = procedure (aHandle: SmallInt) of object;
  TNotifyDataEvent = procedure(aHandle: SmallInt; aData: Pointer; aLength: Cardinal) of object;

  TKMNetServerOverbyte = class
  private
    fSocketServer:TWSocketServer;
    fLastTag: SmallInt;
    fOnError: TGetStrProc;
    fOnClientConnect: THandleEvent;
    fOnClientDisconnect: THandleEvent;
    fOnDataAvailable: TNotifyDataEvent;
    procedure ClientConnect(Sender: TObject; aClient: TWSocketClient; aError: Word);
    procedure ClientDisconnect(Sender: TObject; aClient: TWSocketClient; aError: Word);
    procedure DataAvailable(Sender: TObject; aError: Word);
    function GetMaxHandle: SmallInt;
  public
    constructor Create;
    destructor Destroy; override;
    procedure StartListening(aPort: Word);
    procedure StopListening;
    procedure SendData(aHandle: SmallInt; aData: Pointer; aLength: Cardinal);
    procedure Kick(aHandle: SmallInt);
    function GetIP(aHandle: SmallInt): string;
    function IsValidHandle(aHandle: Integer): Boolean;
    property OnError: TGetStrProc write fOnError;
    property OnClientConnect: THandleEvent write fOnClientConnect;
    property OnClientDisconnect: THandleEvent write fOnClientDisconnect;
    property OnDataAvailable: TNotifyDataEvent write fOnDataAvailable;
  end;


implementation
uses
  Math;


// Tagging starts with some number away from -2 -1 0 used as sender/recipient constants
// and off from usual players indexes 1..8, so we could not confuse them by mistake
const
  FIRST_TAG = 15;


constructor TKMNetServerOverbyte.Create;
var
  wsaData: TWSAData;
begin
  inherited;
  fLastTag := FIRST_TAG-1; //First Client will be fLastTag+1
  if WSAStartup($101, wsaData) <> 0 then
    fOnError('Error in Network');
end;


destructor TKMNetServerOverbyte.Destroy;
begin
  fSocketServer.Free;
  inherited;
end;


procedure TKMNetServerOverbyte.StartListening(aPort: Word);
begin
  FreeAndNil(fSocketServer);
  fSocketServer := TWSocketServer.Create(nil);
  fSocketServer.ComponentOptions := [wsoTcpNoDelay]; //Send packets ASAP (disables Nagle's algorithm)
  fSocketServer.Proto  := 'tcp';
  fSocketServer.Addr   := '0.0.0.0'; //Listen to whole range
  fSocketServer.Port   := IntToStr(aPort); //DONE: Somewhere along the hierarchy we might want to set aPort to be Word
  fSocketServer.Banner := '';
  fSocketServer.OnClientConnect := ClientConnect;
  fSocketServer.OnClientDisconnect := ClientDisconnect;
  fSocketServer.OnDataAvailable := DataAvailable;
  fSocketServer.Listen;
  fSocketServer.SetTcpNoDelayOption; //Send packets ASAP (disables Nagle's algorithm)
end;


procedure TKMNetServerOverbyte.StopListening;
begin
  if fSocketServer <> nil then fSocketServer.Close;
  FreeAndNil(fSocketServer);
  fLastTag := FIRST_TAG-1;
end;


//Someone has connected to us
procedure TKMNetServerOverbyte.ClientConnect(Sender: TObject; aClient: TWSocketClient; aError: Word);
begin
  if aError <> 0 then
  begin
    fOnError('ClientConnect. Error: '+WSocketErrorDesc(aError)+' (#' + IntToStr(aError)+')');
    exit;
  end;

  //Identify index of the Client, so we can address it
  if fLastTag = GetMaxHandle then fLastTag := FIRST_TAG-1; //I'll be surprised if this is ever necessary
  inc(fLastTag);
  aClient.Tag := fLastTag;

  aClient.OnDataAvailable := DataAvailable;
  aClient.ComponentOptions := [wsoTcpNoDelay]; //Send packets ASAP (disables Nagle's algorithm)
  aClient.SetTcpNoDelayOption;
  fOnClientConnect(aClient.Tag);
end;


procedure TKMNetServerOverbyte.ClientDisconnect(Sender: TObject; aClient: TWSocketClient; aError: Word);
begin
  if aError <> 0 then
  begin
    fOnError('ClientDisconnect. Error: '+WSocketErrorDesc(aError)+' (#' + IntToStr(aError)+')');
    //Do not exit because the Client has still disconnected
  end;

  fOnClientDisconnect(aClient.Tag);
end;


//We recieved data from someone
procedure TKMNetServerOverbyte.DataAvailable(Sender: TObject; aError: Word);
const
  BUFFER_SIZE = 10240; //10kb
var
  P: Pointer;
  L: Integer; //L could be -1 when no data is available
begin
  if aError <> 0 then
  begin
    fOnError('DataAvailable. Error: '+WSocketErrorDesc(aError)+' (#' + IntToStr(aError)+')');
    exit;
  end;

  GetMem(P, BUFFER_SIZE+1); //+1 to avoid RangeCheckError when L = BufferSize
  L := TWSocket(Sender).Receive(P, BUFFER_SIZE);

  if L > 0 then //if L=0 then exit;
    fOnDataAvailable(TWSocket(Sender).Tag, P, L);

  FreeMem(P);
end;


//Make sure we send data to specified Client
procedure TKMNetServerOverbyte.SendData(aHandle: SmallInt; aData: Pointer; aLength: Cardinal);
var
  I: Integer;
begin
  for I := 0 to fSocketServer.ClientCount - 1 do
    if fSocketServer.Client[i].Tag = aHandle then
    begin
      if fSocketServer.Client[i].State <> wsClosed then //Sometimes this occurs just before ClientDisconnect
        if fSocketServer.Client[i].Send(aData, aLength) <> aLength then
          fOnError('Overbyte Server: Failed to send packet to client '+IntToStr(aHandle));
    end;
end;


function TKMNetServerOverbyte.GetMaxHandle: SmallInt;
begin
  Result := 32767;
end;


// Take in Integer to check it against actual small range
function TKMNetServerOverbyte.IsValidHandle(aHandle: Integer): Boolean;
begin
  // This is rather poor check that can be refactored to check against real fMaxHandle
  Result := InRange(aHandle, FIRST_TAG, GetMaxHandle);
end;


// Kick the Client specified by the Handle
procedure TKMNetServerOverbyte.Kick(aHandle: SmallInt);
var
  I: Integer;
begin
  for I := 0 to fSocketServer.ClientCount - 1 do
    if fSocketServer.Client[I].Tag = aHandle then
    begin
      if fSocketServer.Client[I].State <> wsClosed then //Sometimes this occurs just before ClientDisconnect
        fSocketServer.Client[I].Close;
      Exit; //Only one Client should have this handle
    end;
end;


function TKMNetServerOverbyte.GetIP(aHandle: SmallInt): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to fSocketServer.ClientCount - 1 do
    if fSocketServer.Client[I].Tag = aHandle then
    begin
      if fSocketServer.Client[I].State <> wsClosed then //Sometimes this occurs just before ClientDisconnect
        Result := fSocketServer.Client[I].GetPeerAddr;
      Exit; //Only one aClient should have this handle
    end;
end;


end.

