unit Runner_Game;
{$I KaM_Remake.inc}
interface
uses
  Forms, Unit_Runner, Windows, SysUtils, Classes, KromUtils, Math,
  Generics.Collections, Generics.Defaults, System.Hash,
  KM_CommonClasses, KM_Defaults, KM_Points, KM_CommonUtils,
  KM_GameApp, KM_Log, KM_HandsCollection, KM_HouseCollection, KM_Resource,
  KM_Terrain, KM_Units, KM_Campaigns, KM_Houses,
  KM_GameParams;


type
  TKMRunnerStone = class(TKMRunnerCommon)
  protected
    procedure SetUp; override;
    procedure Execute(aRun: Integer); override;
    procedure TearDown; override;
  end;

  TKMRunnerFight95 = class(TKMRunnerCommon)
  protected
    procedure SetUp; override;
    procedure Execute(aRun: Integer); override;
    procedure TearDown; override;
  end;

  TKMRunnerAIBuild = class(TKMRunnerCommon)
  private
    HTotal, WTotal, WFTotal, GTotal: Cardinal;
    HAver, WAver, WFAver, GAver: Single;
    HandsCnt, Runs: Integer;
    Time: Cardinal;
  protected
    procedure SetUp; override;
    procedure Execute(aRun: Integer); override;
    procedure TearDown; override;
  end;


implementation
uses
  KM_Exceptions,
  TypInfo, StrUtils, KM_CampaignTypes,
  KM_HandSpectator, KM_ResHouses, KM_Hand, KM_HandTypes, KM_UnitsCollection, KM_UnitGroup,
  KM_GameSettings,
  KM_CommonTypes, KM_MapTypes, KM_FileIO, KM_Game, KM_GameInputProcess, KM_GameTypes, KM_InterfaceGame,
  KM_UnitGroupTypes,
  KM_ResTypes, KM_CampaignClasses;


{ TKMRunnerStone }
procedure TKMRunnerStone.SetUp;
begin
  inherited;
  fResults.ValueCount := 1;
//  fResults.TimesCount := 0;

  FEAT_AI_GENERATE_INFLUENCE := False;
  FEAT_AI_GENERATE_NAVMESH := False;
  DYNAMIC_TERRAIN := False;
end;


procedure TKMRunnerStone.TearDown;
begin
  inherited;
  FEAT_AI_GENERATE_INFLUENCE := True;
  FEAT_AI_GENERATE_NAVMESH := True;
  DYNAMIC_TERRAIN := True;
end;


procedure TKMRunnerStone.Execute(aRun: Integer);
var
  I,K: Integer;
  L: TKMPointList;
  P: TKMPoint;
begin
  //Total amount of stone = 4140
  gTerrain := TKMTerrain.Create;
//  gTerrain.LoadFromFile(ExeDir + 'Maps\StoneMines\StoneMines.map', False);
  gTerrain.LoadFromFile(ExeDir + 'Maps\StoneMinesTest\StoneMinesTest.map', False);

  SetKaMSeed(aRun+1);

  //Stonemining is done programmatically, by iterating through all stone tiles
  //and mining them if conditions are right (like Stonemasons would do)

  L := TKMPointList.Create;
  for I := 1 to gTerrain.MapY - 2 do
  for K := 1 to gTerrain.MapX - 1 do
  if gTerrain.TileIsStone(K,I) > 0 then
    L.Add(KMPoint(K,I));

  I := 0;
  fResults.Value[aRun, 0] := 0;
  repeat
    L.GetRandom(P);

    if gTerrain.TileIsStone(P.X,P.Y) > 0 then
    begin
      if gTerrain.CheckPassability(KMPointBelow(P), tpWalk) then
      begin
        gTerrain.DecStoneDeposit(P);
        fResults.Value[aRun, 0] := fResults.Value[aRun, 0] + 3;
        I := 0;
      end;
    end
    else
      L.Remove(P);

    Inc(I);
    if I > 200 then
      Break;
  until (L.Count = 0);

  FreeAndNil(gTerrain);
end;


{ TKMRunnerFight95 }
procedure TKMRunnerFight95.SetUp;
begin
  inherited;
  fResults.ValueCount := 2;
//  fResults.TimesCount := 2*60*10;

  DYNAMIC_TERRAIN := False;
end;


procedure TKMRunnerFight95.TearDown;
begin
  inherited;
  DYNAMIC_TERRAIN := True;
end;


procedure TKMRunnerFight95.Execute(aRun: Integer);
begin
  gGameApp.NewEmptyMap(128, 128);
  SetKaMSeed(aRun + 1);

  //fPlayers[0].AddUnitGroup(utKnight, KMPoint(63, 64), dir_E, 8, 24);
  //fPlayers[1].AddUnitGroup(utSwordFighter, KMPoint(65, 64), dir_W, 8, 24);

  //fPlayers[0].AddUnitGroup(utSwordFighter, KMPoint(63, 64), dir_E, 8, 24);
  //fPlayers[1].AddUnitGroup(utPikeman, KMPoint(65, 64), dir_W, 8, 24);

  //fPlayers[0].AddUnitGroup(utPikeman, KMPoint(63, 64), dir_E, 8, 24);
  //fPlayers[1].AddUnitGroup(utKnight, KMPoint(65, 64), dir_W, 8, 24);

  gHands[0].AddUnitGroup(utSwordFighter, KMPoint(63, 64), TKMDirection(dirE), 8, 24);
  gHands[1].AddUnitGroup(utSwordFighter, KMPoint(65, 64), TKMDirection(dirW), 8, 24);

  gHands[1].UnitGroups[0].OrderAttackUnit(gHands[0].Units[0], True);

  SimulateGame;

  fResults.Value[aRun, 0] := gHands[0].Stats.GetUnitQty(utAny);
  fResults.Value[aRun, 1] := gHands[1].Stats.GetUnitQty(utAny);

  gGameApp.StopGame(grSilent);
end;


{ TKMRunnerAIBuild }
procedure TKMRunnerAIBuild.SetUp;
begin
  inherited;
  if gLog = nil then
    gLog := TKMLog.Create(ExeDir + 'Utils\Runner\Runner_Log.log');

  fResults.ValueCount := 6;
//  fResults.TimesCount := 60*60*10;
  fResults.TimesCount := 10;
  HTotal := 0;
  HAver := 0;
  WTotal := 0;
  WAver := 0;
  GTotal := 0;
  GAver := 0;
  Runs := 0;
  Time := TimeGet;

  //SKIP_LOADING_CURSOR := True;
end;


procedure TKMRunnerAIBuild.TearDown;
begin
  //
  HAver := HTotal / (Runs*HandsCnt);
  WAver := WTotal / (Runs*HandsCnt);
  WFAver := WFTotal / (Runs*HandsCnt);
  GAver := GTotal / (Runs*HandsCnt);

  gLog.AddTime('==================================================================');
  gLog.AddTime('HAver: %3.2f  WAver: %3.2f  WFAver: %3.2f  GAver: %5.2f', [HAver, WAver, WFAver, GAver]);
  gLog.AddTime('TimeAver: ' + IntToStr(Round(TimeSince(Time)/Runs)));
  gLog.AddTime('Time: ' + IntToStr(TimeSince(Time)));
  inherited;
end;


procedure TKMRunnerAIBuild.Execute(aRun: Integer);
var Str: String;
    I: Integer;
    HRun, HRunT, WRun, WRunT, WFRun, WFRunT, GRun, GRunT: Cardinal;
    StartT: Cardinal;
begin
  //gGameApp.NewSingleMap(ExtractFilePath(ParamStr(0)) + '..\..\MapsMP\Cursed Ravine\Cursed Ravine.dat', 'Cursed Ravine');
  gGameApp.NewSingleMap(ExtractFilePath(ParamStr(0)) + '..\..\Maps\GA_'+IntToStr(aRun+1)+'\GA_'+IntToStr(aRun+1)+'.dat', 'GA');
  Inc(Runs);
  gMySpectator.Hand.FogOfWar.RevealEverything;
  gGameApp.Game.GamePlayInterface.Viewport.PanTo(KMPointF(136, 25), 0);
  gGameApp.Game.GamePlayInterface.Viewport.Zoom := 0.25;

  SetKaMSeed(aRun + 1);
  StartT := TimeGet;

  SimulateGame;

  gGameApp.Game.Save('AI Build #' + IntToStr(aRun), Now);

  {fResults.Value[aRun, 0] := gHands[0].Stats.GetWarriorsTrained;
  fResults.Value[aRun, 1] := gHands[1].Stats.GetWarriorsTrained;
  fResults.Value[aRun, 2] := gHands[2].Stats.GetWarriorsTrained;
  fResults.Value[aRun, 3] := gHands[3].Stats.GetWarriorsTrained;
  fResults.Value[aRun, 4] := gHands[4].Stats.GetWarriorsTrained;
  fResults.Value[aRun, 5] := gHands[5].Stats.GetWarriorsTrained;}

  {fResults.Value[aRun, 0] := gHands[0].Stats.GetGoodsProduced(rt_Stone);
  fResults.Value[aRun, 1] := gHands[1].Stats.GetGoodsProduced(rt_Stone);
  fResults.Value[aRun, 2] := gHands[2].Stats.GetGoodsProduced(rt_Stone);
  fResults.Value[aRun, 3] := gHands[3].Stats.GetGoodsProduced(rt_Stone);
  fResults.Value[aRun, 4] := gHands[4].Stats.GetGoodsProduced(rt_Stone);}

//  fResults.Value[aRun, 0] := gHands[0].Stats.GetHousesBuilt;
//  fResults.Value[aRun, 1] := gHands[1].Stats.GetHousesBuilt;
//  fResults.Value[aRun, 2] := gHands[2].Stats.GetHousesBuilt;
//  fResults.Value[aRun, 3] := gHands[3].Stats.GetHousesBuilt;
//  fResults.Value[aRun, 4] := gHands[4].Stats.GetHousesBuilt;
//  fResults.Value[aRun, 5] := gHands[5].Stats.GetHousesBuilt;

  gLog.AddTime('------- Run ' + IntToStr(Runs));
  HandsCnt := gHands.Count - 1;
  HRunT := 0;
  WRunT := 0;
  WFRunT := 0;
  GRunT := 0;
  for I := 1 to HandsCnt do
  begin
    Str := '';
    HRun := gHands[I].Stats.GetHousesBuilt;
    HRunT := HRunT + HRun;
    HTotal := HTotal + HRun;
    WRun := gHands[I].Stats.GetWarriorsTrained;
    WTotal := WTotal + WRun;
    WRunT := WRunT + WRun;
    WFRun := gHands[I].Stats.GetWaresProduced(wtWarfare);
    WFTotal := WFTotal + WFRun;
    WFRunT := WFRunT + WFRun;
    GRun := gHands[I].Stats.GetWaresProduced(wtAll);
    GTotal := GTotal + GRun;
    GRunT := GRunT + GRun;
    Str := Str + Format('Hand%d: H: %d  W: %d  WF: %d  G: %d', [I, HRun, WRun, WFRun, GRun]);
    gLog.AddTime(Str);
  end;
  gLog.AddTime('HRunAver: %3.2f  WRunAver: %3.2f  WFRunAver: %3.2f  GRunAver: %5.2f',
               [HRunT/HandsCnt, WRunT/HandsCnt, WFRunT/HandsCnt, GRunT/HandsCnt]);
  gLog.AddTime('Time: ' + IntToStr(TimeSince(StartT)));

  gGameApp.StopGame(grSilent);
end;


initialization
  RegisterRunner(TKMRunnerStone);
  RegisterRunner(TKMRunnerFight95);
  RegisterRunner(TKMRunnerAIBuild);
end.
