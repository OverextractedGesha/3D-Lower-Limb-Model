unit uMainFormDelphi;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, System.Types, System.Math, Vcl.Graphics, Vcl.Controls,
  Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls,
  VCLTee.TeEngine, VCLTee.Series, VCLTee.TeeProcs, VCLTee.Chart,
  uBiomechTypes, uKneeSimEngine, uModelFormDelphi;

type
  TMainFormDelphi = class(TForm)
    pnlLimb: TPanel;
    pbLimb: TPaintBox;
    pnlControls: TPanel;
    btnFES: TButton;
    btnModel: TButton;
    btnExtension: TButton;
    btnClose: TButton;
    lblStimTitle: TLabel;
    tbStimS1: TTrackBar;
    lblStimVal: TLabel;
    chtAngle: TChart;
    chtVel: TChart;
    chtLength: TChart;
    chtMusTorque: TChart;
    chtFvsL: TChart;
    chtFvsV: TChart;
    chtGravTorque: TChart;
    chtLvsV: TChart;
    TimerSim: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure pbLimbPaint(Sender: TObject);
    procedure btnFESClick(Sender: TObject);
    procedure btnModelClick(Sender: TObject);
    procedure btnExtensionClick(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);
    procedure tbStimS1Change(Sender: TObject);
    procedure TimerSimTimer(Sender: TObject);
  private
    FEngine: TKneeSimEngine;
    FFESMode: Boolean;
    FBodyHeightCm: Double;
    FPlotSubStepCounter: Integer;
    serAngle: TLineSeries;
    serVel: TLineSeries;
    serLength: TLineSeries;
    serMusTorque: TLineSeries;
    serFvsL: TLineSeries;
    serFvsV: TLineSeries;
    serGravTorque: TLineSeries;
    serLvsV: TLineSeries;
    function SetupChart(AChart: TChart; const ALegendTitle, AXTitle, AYTitle: string;
      AShowPoints: Boolean): TLineSeries;
    procedure ClearAllCharts;
    procedure AppendStateToCharts;
    procedure UpdateStimLabel;
    procedure LayoutGrid;
  public
  end;

var
  MainFormDelphi: TMainFormDelphi;

implementation

{$R *.dfm}

const
  SIM_DT = 0.001;         { 1 ms RK4 integration step }
  STEPS_PER_TICK = 20;    { 20 ms per timer tick -> real-time }
  PLOT_STRIDE = 5;        { Plot every 5 ms (200 Hz) }
  MAX_SIM_TIME = 3.0;     { Stop automatically after 3.0 s }

procedure TMainFormDelphi.FormCreate(Sender: TObject);
begin
  FBodyHeightCm := DEFAULT_BH * 100.0;
  FEngine := TKneeSimEngine.Create(DEFAULT_BW, DEFAULT_BH);
  FFESMode := False;
  FPlotSubStepCounter := 0;

  serAngle := SetupChart(chtAngle, 'Knee angle (deg)', 'Time (s)', 'deg', False);
  serVel := SetupChart(chtVel, 'Knee vel (deg/sec)', 'Time (s)', 'deg/s', False);
  serLength := SetupChart(chtLength, 'Fibre Length (m)', 'Time (s)', 'm', False);
  serMusTorque := SetupChart(chtMusTorque, 'MusTorque (Nm)', 'Time (s)', 'Nm', False);
  serFvsL := SetupChart(chtFvsL, 'F(X(t)) vs length', 'Length (m)', 'Force (N)', True);
  serFvsV := SetupChart(chtFvsV, 'F(X(t)) vs vel', 'Vel (m/s)', 'Force (N)', True);
  serGravTorque := SetupChart(chtGravTorque, 'Grav Torque (Nm)', 'Time (s)', 'Nm', False);
  serLvsV := SetupChart(chtLvsV, 'length vs vel', 'Vel (m/s)', 'Length (m)', True);

  UpdateStimLabel;
  LayoutGrid;
  AppendStateToCharts;
end;

procedure TMainFormDelphi.FormDestroy(Sender: TObject);
begin
  TimerSim.Enabled := False;
  FEngine.Free;
  FEngine := nil;
end;

function TMainFormDelphi.SetupChart(AChart: TChart;
  const ALegendTitle, AXTitle, AYTitle: string; AShowPoints: Boolean): TLineSeries;
begin
  AChart.View3D := False;
  AChart.Color := clWhite;
  AChart.Legend.Visible := True;
  AChart.Title.Visible := False;
  AChart.BottomAxis.Title.Caption := AXTitle;
  AChart.LeftAxis.Title.Caption := AYTitle;

  Result := TLineSeries.Create(AChart);
  Result.ParentChart := AChart;
  Result.Title := ALegendTitle;
  Result.SeriesColor := clRed;
  Result.LinePen.Color := clRed;
  Result.LinePen.Width := 2;
  Result.XValues.Order := loNone;
  Result.Pointer.Visible := AShowPoints;
  if AShowPoints then
  begin
    Result.Pointer.Style := psCircle;
    Result.Pointer.HorizSize := 2;
    Result.Pointer.VertSize := 2;
    Result.Pointer.Color := clRed;
  end;
end;

procedure TMainFormDelphi.FormResize(Sender: TObject);
begin
  LayoutGrid;
end;

procedure TMainFormDelphi.LayoutGrid;
const
  PAD = 6;
  CTRL_H = 68;
var
  W, H, TopH, BotH, LeftW, RightX, ColW, UpperChartH: Integer;
begin
  W := ClientWidth;
  H := ClientHeight;
  if (W < 400) or (H < 300) then
    Exit;

  TopH := Round(H * 0.62);
  BotH := H - TopH - PAD * 3;
  LeftW := Round(W * 0.34);
  RightX := PAD * 2 + LeftW;
  ColW := (W - RightX - PAD * 2) div 2;
  UpperChartH := (TopH - CTRL_H - PAD * 2) div 2;

  pnlLimb.SetBounds(PAD, PAD, LeftW, TopH - PAD);
  pnlControls.SetBounds(RightX, PAD, W - RightX - PAD, CTRL_H);

  chtAngle.SetBounds(RightX, PAD + CTRL_H + PAD, ColW, UpperChartH);
  chtVel.SetBounds(RightX + ColW + PAD, PAD + CTRL_H + PAD, W - (RightX + ColW + PAD) - PAD, UpperChartH);
  chtLength.SetBounds(RightX, PAD + CTRL_H + PAD * 2 + UpperChartH, ColW, TopH - (CTRL_H + PAD * 2 + UpperChartH));
  chtMusTorque.SetBounds(RightX + ColW + PAD, PAD + CTRL_H + PAD * 2 + UpperChartH,
    W - (RightX + ColW + PAD) - PAD, TopH - (CTRL_H + PAD * 2 + UpperChartH));

  ColW := (W - PAD * 5) div 4;
  chtFvsL.SetBounds(PAD, TopH + PAD, ColW, BotH);
  chtFvsV.SetBounds(PAD * 2 + ColW, TopH + PAD, ColW, BotH);
  chtGravTorque.SetBounds(PAD * 3 + ColW * 2, TopH + PAD, ColW, BotH);
  chtLvsV.SetBounds(PAD * 4 + ColW * 3, TopH + PAD, W - (PAD * 4 + ColW * 3) - PAD, BotH);
end;

procedure TMainFormDelphi.ClearAllCharts;
begin
  serAngle.Clear;
  serVel.Clear;
  serLength.Clear;
  serMusTorque.Clear;
  serFvsL.Clear;
  serFvsV.Clear;
  serGravTorque.Clear;
  serLvsV.Clear;
end;

procedure TMainFormDelphi.AppendStateToCharts;
var
  S: TKneeState;
  Deg, DegVel: Double;
begin
  S := FEngine.State;
  Deg := S.Theta * RAD_TO_DEG;
  DegVel := S.Omega * RAD_TO_DEG;

  serAngle.AddXY(S.Time, Deg);
  serVel.AddXY(S.Time, DegVel);
  serLength.AddXY(S.Time, S.FiberLength);
  serMusTorque.AddXY(S.Time, S.MusTorque);
  serFvsL.AddXY(S.FiberLength, S.F_X_t);
  serFvsV.AddXY(S.FiberVel, S.F_X_t);
  serGravTorque.AddXY(S.Time, S.GravTorque);
  serLvsV.AddXY(S.FiberVel, S.FiberLength);
end;

procedure TMainFormDelphi.UpdateStimLabel;
var
  S1, U: Double;
begin
  if FEngine = nil then
    Exit;
  S1 := tbStimS1.Position / 100.0;
  U := FEngine.ComputeRecruitment(S1);
  lblStimVal.Caption := Format('s1 = %.2f  (u = %.3f)', [S1, U]);
end;

procedure TMainFormDelphi.pbLimbPaint(Sender: TObject);
var
  Bmp: TBitmap;
  S: TKneeState;
  Anthro: TAnthropometricData;
  W, H: Integer;
  ScalePx: Double;
  HipX, HipY, KneeX, KneeY, AnkleX, AnkleY, FootX, FootY: Integer;
  FootAngle: Double;

  procedure DrawJoint(ACanvas: TCanvas; AX, AY: Integer);
  begin
    ACanvas.Brush.Color := clBlue;
    ACanvas.Pen.Color := clBlue;
    ACanvas.Ellipse(AX - 6, AY - 6, AX + 6, AY + 6);
  end;

begin
  if FEngine = nil then
    Exit;
  W := pbLimb.Width;
  H := pbLimb.Height;
  if (W <= 0) or (H <= 0) then
    Exit;

  S := FEngine.State;
  Anthro := FEngine.Anthro;

  Bmp := TBitmap.Create;
  try
    Bmp.SetSize(W, H);
    Bmp.Canvas.Brush.Color := clBlack;
    Bmp.Canvas.FillRect(Rect(0, 0, W, H));

    ScalePx := 0.42 * H / (Anthro.L1 + 0.2);
    if (Anthro.L1 + Anthro.L2 + Anthro.L3) * ScalePx > W * 0.85 then
      ScalePx := (W * 0.82) / (Anthro.L1 + Anthro.L2 + Anthro.L3);

    HipX := Round(W * 0.14);
    HipY := Round(H * 0.34);

    KneeX := HipX + Round(Anthro.L1 * ScalePx);
    KneeY := HipY;

    AnkleX := KneeX + Round(Anthro.L2 * ScalePx * Cos(S.Theta));
    AnkleY := KneeY + Round(Anthro.L2 * ScalePx * Sin(S.Theta));

    FootAngle := S.Theta - Pi * 0.5;
    FootX := AnkleX + Round(Anthro.L3 * ScalePx * Cos(FootAngle));
    FootY := AnkleY + Round(Anthro.L3 * ScalePx * Sin(FootAngle));

    Bmp.Canvas.Pen.Color := clRed;
    Bmp.Canvas.Pen.Width := 5;
    Bmp.Canvas.MoveTo(HipX, HipY);
    Bmp.Canvas.LineTo(KneeX, KneeY);
    Bmp.Canvas.LineTo(AnkleX, AnkleY);
    Bmp.Canvas.LineTo(FootX, FootY);

    DrawJoint(Bmp.Canvas, HipX, HipY);
    DrawJoint(Bmp.Canvas, KneeX, KneeY);
    DrawJoint(Bmp.Canvas, AnkleX, AnkleY);

    Bmp.Canvas.Brush.Style := bsClear;
    Bmp.Canvas.Font.Color := clSilver;
    Bmp.Canvas.Font.Size := 9;
    Bmp.Canvas.TextOut(10, H - 42,
      Format('t = %.3f s   Theta = %.1f deg   Omega = %.1f deg/s',
      [S.Time, S.Theta * RAD_TO_DEG, S.Omega * RAD_TO_DEG]));
    Bmp.Canvas.TextOut(10, H - 22,
      Format('Act a = %.3f   MusTau = %.1f Nm   GravTau = %.1f Nm',
      [S.Activation, S.MusTorque, S.GravTorque]));

    pbLimb.Canvas.Draw(0, 0, Bmp);
  finally
    Bmp.Free;
  end;
end;

procedure TMainFormDelphi.btnFESClick(Sender: TObject);
begin
  TimerSim.Enabled := False;
  FFESMode := True;
  FPlotSubStepCounter := 0;
  FEngine.Reset(90.0, 0.0);
  ClearAllCharts;
  AppendStateToCharts;
  pbLimb.Invalidate;
  TimerSim.Enabled := True;
end;

procedure TMainFormDelphi.btnExtensionClick(Sender: TObject);
begin
  TimerSim.Enabled := False;
  FFESMode := False;
  FPlotSubStepCounter := 0;
  if FEngine.State.Theta * RAD_TO_DEG > 75.0 then
  begin
    FEngine.Reset(10.0, 0.0);
    ClearAllCharts;
    AppendStateToCharts;
  end;
  pbLimb.Invalidate;
  TimerSim.Enabled := True;
end;

procedure TMainFormDelphi.btnModelClick(Sender: TObject);
var
  ModelDlg: TModelFormDelphi;
  ThetaVec, OmegaVec: TVector3;
  WasRunning: Boolean;
begin
  if FEngine = nil then
    Exit;

  WasRunning := TimerSim.Enabled;
  TimerSim.Enabled := False;
  try
    ThetaVec[0] := Pi * 0.5;
    ThetaVec[1] := -FEngine.State.Theta;
    ThetaVec[2] := -Pi * 0.5;

    OmegaVec[0] := 0.0;
    OmegaVec[1] := -FEngine.State.Omega;
    OmegaVec[2] := 0.0;

    ModelDlg := TModelFormDelphi.Create(nil);
    try
      ModelDlg.LoadParameters(FEngine.Anthro.BW, FBodyHeightCm, ThetaVec, OmegaVec);
      if ModelDlg.ShowModal = mrOk then
      begin
        FBodyHeightCm := ModelDlg.BodyHeightCm;
        FEngine.SetAnthropometry(ModelDlg.BodyWeightKg, FBodyHeightCm / 100.0);
        pbLimb.Invalidate;
      end;
    finally
      ModelDlg.Free;
    end;
  finally
    TimerSim.Enabled := WasRunning;
  end;
end;

procedure TMainFormDelphi.btnCloseClick(Sender: TObject);
begin
  Close;
end;

procedure TMainFormDelphi.tbStimS1Change(Sender: TObject);
begin
  UpdateStimLabel;
end;

procedure TMainFormDelphi.TimerSimTimer(Sender: TObject);
var
  I: Integer;
  S1: Double;
begin
  if FEngine = nil then
    Exit;
  S1 := tbStimS1.Position / 100.0;
  for I := 1 to STEPS_PER_TICK do
  begin
    if FEngine.State.Time >= MAX_SIM_TIME then
    begin
      TimerSim.Enabled := False;
      Break;
    end;
    FEngine.Step(SIM_DT, S1, FFESMode);
    Inc(FPlotSubStepCounter);
    if FPlotSubStepCounter >= PLOT_STRIDE then
    begin
      FPlotSubStepCounter := 0;
      AppendStateToCharts;
    end;
  end;
  pbLimb.Invalidate;
end;

end.
