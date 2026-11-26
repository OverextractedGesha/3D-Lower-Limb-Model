unit uModelFormDelphi;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  System.UITypes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.StdCtrls, Vcl.ExtCtrls,
  uBiomechCore;

type
  TModelFormDelphi = class(TForm)
    pnlTop: TPanel;
    lblBW: TLabel;
    edtBW: TEdit;
    lblBH: TLabel;
    edtBH: TEdit;
    btnApply: TButton;
    btnClose: TButton;
    memoModel: TMemo;
    procedure btnApplyClick(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);
  private
    FBW: Double;
    FBHCm: Double;
    FTheta: TVector3;
    FOmega: TVector3;
    FApplied: Boolean;
    procedure RefreshDisplay;
  public
    procedure LoadParameters(ABW, ABHCm: Double; const ATheta, AOmega: TVector3);
    property BodyWeightKg: Double read FBW;
    property BodyHeightCm: Double read FBHCm;
    property Applied: Boolean read FApplied;
  end;

implementation

{$R *.dfm}

procedure TModelFormDelphi.LoadParameters(ABW, ABHCm: Double; const ATheta, AOmega: TVector3);
begin
  FBW := ABW;
  FBHCm := ABHCm;
  FTheta := ATheta;
  FOmega := AOmega;
  FApplied := False;
  edtBW.Text := FormatFloat('0.##', FBW);
  edtBH.Text := FormatFloat('0.##', FBHCm);
  RefreshDisplay;
end;

procedure TModelFormDelphi.RefreshDisplay;
var
  Anthro: TAnthropometricData;
  Lag: TLagrange3DOFResult;
  Lines: TStringList;
begin
  Anthro := ComputeAnthropometry(FBW, FBHCm / 100.0);
  Lag := EvaluateLagrange3DOF(Anthro, FTheta, FOmega);

  Lines := TStringList.Create;
  try
    Lines.Add('=== WINTER (2009) ANTHROPOMETRIC SEGMENTAL PARAMETERS ===');
    Lines.Add(Format('Body Weight (BW): %.2f kg   |   Body Height (BH): %.2f cm (%.4f m)',
      [Anthro.BW, Anthro.BH * 100.0, Anthro.BH]));
    Lines.Add('');
    Lines.Add(Format('Thigh (Seg 1): L1 = %.4f m,  M1 = %.4f kg,  A1 = %.4f m,  I1 = %.6f kg*m^2',
      [Anthro.L1, Anthro.M1, Anthro.A1, Anthro.I1]));
    Lines.Add(Format('Shank (Seg 2): L2 = %.4f m,  M2 = %.4f kg,  A2 = %.4f m,  I2 = %.6f kg*m^2',
      [Anthro.L2, Anthro.M2, Anthro.A2, Anthro.I2]));
    Lines.Add(Format('Foot  (Seg 3): L3 = %.4f m,  M3 = %.4f kg,  A3 = %.4f m,  I3 = %.6f kg*m^2',
      [Anthro.L3, Anthro.M3, Anthro.A3, Anthro.I3]));
    Lines.Add('');
    Lines.Add(Format('Seated 1-DOF Knee Inertia IKnee           = %.6f kg*m^2', [Anthro.IKnee]));
    Lines.Add(Format('Seated Gravity Moment Coeff (M2*A2+M3*L2)g = %.4f N*m', [Anthro.GravMomentCoeff]));
    Lines.Add('');
    Lines.Add('=== 3-DOF LAGRANGIAN MODEL EVALUATION ===');
    Lines.Add(Format('State Theta (rad): [Hip=%.4f, Knee=%.4f, Ankle=%.4f]',
      [FTheta[0], FTheta[1], FTheta[2]]));
    Lines.Add(Format('State Omega (rad/s): [Hip=%.4f, Knee=%.4f, Ankle=%.4f]',
      [FOmega[0], FOmega[1], FOmega[2]]));
    Lines.Add('');
    Lines.Add('Inertia Matrix M(theta) [kg*m^2]:');
    Lines.Add(Format('  [ %10.6f  %10.6f  %10.6f ]', [Lag.M[0, 0], Lag.M[0, 1], Lag.M[0, 2]]));
    Lines.Add(Format('  [ %10.6f  %10.6f  %10.6f ]', [Lag.M[1, 0], Lag.M[1, 1], Lag.M[1, 2]]));
    Lines.Add(Format('  [ %10.6f  %10.6f  %10.6f ]', [Lag.M[2, 0], Lag.M[2, 1], Lag.M[2, 2]]));
    Lines.Add('');
    Lines.Add('Coriolis / Centrifugal Matrix C(theta, omega) [N*m*s/rad]:');
    Lines.Add(Format('  [ %10.6f  %10.6f  %10.6f ]', [Lag.C[0, 0], Lag.C[0, 1], Lag.C[0, 2]]));
    Lines.Add(Format('  [ %10.6f  %10.6f  %10.6f ]', [Lag.C[1, 0], Lag.C[1, 1], Lag.C[1, 2]]));
    Lines.Add(Format('  [ %10.6f  %10.6f  %10.6f ]', [Lag.C[2, 0], Lag.C[2, 1], Lag.C[2, 2]]));
    Lines.Add('');
    Lines.Add('Gravity Vector G(theta) [N*m]:');
    Lines.Add(Format('  [ Hip = %9.4f,  Knee = %9.4f,  Ankle = %9.4f ]',
      [Lag.G[0], Lag.G[1], Lag.G[2]]));
    Lines.Add('');
    Lines.Add('Passive Viscoelastic Joint Torques (Riener & Edrich 1999) [N*m]:');
    Lines.Add(Format('  TauP1 (Ankle) = %9.4f N*m', [Lag.TauP1]));
    Lines.Add(Format('  TauP2 (Knee)  = %9.4f N*m', [Lag.TauP2]));
    Lines.Add(Format('  TauP3 (Hip)   = %9.4f N*m', [Lag.TauP3]));

    memoModel.Lines.Assign(Lines);
  finally
    Lines.Free;
  end;
end;

procedure TModelFormDelphi.btnApplyClick(Sender: TObject);
var
  NewBW, NewBH: Double;
begin
  if (not TryStrToFloat(Trim(edtBW.Text), NewBW)) or (NewBW <= 10.0) or (NewBW > 300.0) then
  begin
    MessageDlg('Please enter a valid Body Weight in kg (10..300).', mtWarning, [mbOK], 0);
    Exit;
  end;
  if (not TryStrToFloat(Trim(edtBH.Text), NewBH)) or (NewBH <= 50.0) or (NewBH > 260.0) then
  begin
    MessageDlg('Please enter a valid Body Height in cm (50..260).', mtWarning, [mbOK], 0);
    Exit;
  end;

  FBW := NewBW;
  FBHCm := NewBH;
  FApplied := True;
  RefreshDisplay;
end;

procedure TModelFormDelphi.btnCloseClick(Sender: TObject);
begin
  if FApplied then
    ModalResult := mrOk
  else
    ModalResult := mrCancel;
end;

end.
