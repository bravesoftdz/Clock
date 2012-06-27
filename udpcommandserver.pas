//
// Copyright 2012 Shaun Simpson
// shauns2029@gmail.com
//

unit udpcommandserver;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, LCLProc, SyncObjs,

  // synapse
  blcksock;

type

  TRemoteCommand = (rcomNone, rcomNext, rcomMusic, rcomSleep, rcomPause, rcomVolumeUp, rcomVolumeDown);

  { TCOMServerThread }

  TCOMServerThread = class(TThread)
  private
    FPort: integer;
    FPlaying: string;
    FWeatherReport: string;

    procedure SetPlaying(const AValue: string);
    procedure SetWeatherReport(const AValue: string);
  protected
    FCommand: TRemoteCommand;
    FCritical: TCriticalSection;

    procedure Execute; override;
  public
    function GetCommnd: TRemoteCommand;

    constructor Create(Port: integer);
    destructor Destroy; override;
  published
    property Playing: string write SetPlaying;
    property WeatherReport: string write SetWeatherReport;
  end;

  TCOMServer = class
  private
    FCOMServerThread: TCOMServerThread;
    procedure SetPlaying(const AValue: string);
    procedure SetWeatherReport(const AValue: string);
  public
    function GetCommand: TRemoteCommand;

    constructor Create(Port: integer);
    destructor Destroy; override;
  published
    property Playing: string write SetPlaying;
    property WeatherReport: string write SetWeatherReport;
  end;

implementation

{ TCOMServer }

procedure TCOMServer.SetPlaying(const AValue: string);
begin
  FCOMServerThread.Playing := AValue;
end;

procedure TCOMServer.SetWeatherReport(const AValue: string);
begin
  FCOMServerThread.WeatherReport := AValue;
end;

function TCOMServer.GetCommand: TRemoteCommand;
begin
  Result := FCOMServerThread.GetCommnd;
end;

constructor TCOMServer.Create(Port: integer);
begin
  inherited Create;

  FCOMServerThread := TCOMServerThread.Create(Port);
end;

destructor TCOMServer.Destroy;
begin
  FCOMServerThread.Terminate;
  FCOMServerThread.WaitFor;
  FCOMServerThread.Free;

  inherited Destroy;
end;


{ TCOMServerThread }

procedure TCOMServerThread.SetPlaying(const AValue: string);
begin
  FCritical.Enter;
  FPlaying := AValue;
  FCritical.Leave;
end;

procedure TCOMServerThread.SetWeatherReport(const AValue: string);
begin
  FCritical.Enter;
  FWeatherReport := AValue;
  FCritical.Leave;
end;

procedure TCOMServerThread.Execute;
var
  Socket: TUDPBlockSocket;
  Buffer: string;
  Size: Integer;
  i: Integer;
  DataBuff: string;
  Pos: integer;
  Total: integer;
  PakNo: integer;
begin
  Socket := TUDPBlockSocket.Create;
  try
    Socket.Bind('0.0.0.0', IntToStr(FPort));
    try
      if Socket.LastError <> 0 then
      begin
        raise Exception.CreateFmt('Bind failed with error code %d', [Socket.LastError]);
        Exit;
      end;

      while not Terminated do
      begin
        // wait one second for new packet
        Buffer := Socket.RecvPacket(1000);

        if Socket.LastError = 0 then
        begin
          if Buffer = 'CLOCK:NEXT' then
          begin
            FCritical.Enter;
            FCommand := rcomNext;
            FCritical.Leave;
          end
          else if Buffer = 'CLOCK:MUSIC' then
          begin
            FCritical.Enter;
            FCommand := rcomMusic;
            FCritical.Leave;
          end
          else if Buffer = 'CLOCK:SLEEP' then
          begin
            FCritical.Enter;
            FCommand := rcomSleep;
            FCritical.Leave;
          end
          else if Buffer = 'CLOCK:PAUSE' then
          begin
            FCritical.Enter;
            FCommand := rcomPause;
            FCritical.Leave;
          end
          else if Buffer = 'CLOCK:VOLUP' then
          begin
            FCritical.Enter;
            FCommand := rcomVolumeUp;
            FCritical.Leave;
          end
          else if Buffer = 'CLOCK:VOLDOWN' then
          begin
            FCritical.Enter;
            FCommand := rcomVolumeDown;
            FCritical.Leave;
          end
          else if Buffer = 'CLOCK:PLAYING' then
          begin
            FCritical.Enter;
            Socket.SendString(FPlaying);
            FCritical.Leave;
          end
          else if Buffer = 'CLOCK:WEATHER' then
          begin
            FCritical.Enter;
            Socket.SendString(FWeatherReport);
            FCritical.Leave;
          end;
        end;

        // minimal sleep
        if Buffer = '' then
          Sleep(10);
      end;

    finally
      Socket.CloseSocket;
    end;
  finally
    Socket.Free;
  end;
end;

function TCOMServerThread.GetCommnd: TRemoteCommand;
begin
  FCritical.Enter;
  Result := FCommand;
  FCommand := rcomNone;
  FCritical.Leave;
end;

constructor TCOMServerThread.Create(Port: integer);
begin
  inherited Create(False);

  FCritical := TCriticalSection.Create;
  FCommand := rcomNone;
  FPlaying := '--------';
  FWeatherReport := '';
  FPort := Port;
end;

destructor TCOMServerThread.Destroy;
begin
  FCritical.Free;

  inherited Destroy;
end;

end.


