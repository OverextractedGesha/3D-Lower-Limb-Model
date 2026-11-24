unit uKneeSimEngine;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  uBiomechTypes, uAnthropometry;

type
  TKneeSimEngine = class
  private
    FAnthro: TAnthropometricData;
    FMuscle: TMuscleParams;
    FState: TKneeState;
    procedure InitDefaultMuscle;
    procedure EvaluateAt(ATheta, AOmega, AAct, AU: Double;
      out dTheta, dOmega, dAct: Double; out AOutState: TKneeState);
  public
    constructor Create(ABW: Double = DEFAULT_BW; ABH: Double = DEFAULT_BH);
    destructor Destroy; override;
    procedure SetAnthropometry(ABW, ABH: Double);
    procedure Reset(AInitialThetaDeg: Double = 90.0; AInitialActivation: Double = 0.0);
    procedure Step(ADt: Double; AStimS1: Double; AFESMode: Boolean);
    function ComputeRecruitment(AS1: Double): Double;
    property Anthro: TAnthropometricData read FAnthro;
    property Muscle: TMuscleParams read FMuscle;
    property State: TKneeState read FState;
  end;

implementation

uses
  Math;

function Clamp(AVal, AMin, AMax: Double): Double;
begin
  if AVal < AMin then
    Result := AMin
  else if AVal > AMax then
    Result := AMax
  else
    Result := AVal;
end;

function SafeExp(AX: Double): Double;
begin
  Result := Exp(Clamp(AX, -40.0, 40.0));
end;

{ TKneeSimEngine }

constructor TKneeSimEngine.Create(ABW, ABH: Double);
begin
  inherited Create;
  FAnthro := ComputeAnthropometry(ABW, ABH);
  InitDefaultMuscle;
  Reset(90.0, 0.0);
end;

destructor TKneeSimEngine.Destroy;
begin
  inherited Destroy;
end;

procedure TKneeSimEngine.InitDefaultMuscle;
begin
  FMuscle.Fmax := 5000.0;
  FMuscle.Lopt := 0.09;
  FMuscle.R_ma := 0.048;
  FMuscle.ThetaOpt := Pi / 2.0; { 90 deg hanging knee -> L = 0.09 m }
  FMuscle.Vmax := 10.0 * FMuscle.Lopt;
  FMuscle.Tr := 0.100;  { 100 ms }
  FMuscle.Tf := 0.150;  { 150 ms }
  FMuscle.B_damp := 1.5;
end;

procedure TKneeSimEngine.SetAnthropometry(ABW, ABH: Double);
begin
  FAnthro := ComputeAnthropometry(ABW, ABH);
end;

function TKneeSimEngine.ComputeRecruitment(AS1: Double): Double;
var
  S1Clamped: Double;
begin
  S1Clamped := Clamp(AS1, 0.0, 1.0);
  Result := 0.5 * Tanh(15.0 * (S1Clamped - 0.5)) + 0.5;
end;

procedure TKneeSimEngine.EvaluateAt(ATheta, AOmega, AAct, AU: Double;
  out dTheta, dOmega, dAct: Double; out AOutState: TKneeState);
var
  ActClamped, TauConv, L, V, Fl, Fv, VNorm: Double;
  Fm, TauMus, TauGrav, TauElast, TauDamp, Alpha: Double;
begin
  ActClamped := Clamp(AAct, 0.0, 1.0);

  if AU > ActClamped then
    TauConv := FMuscle.Tr
  else
    TauConv := FMuscle.Tf;

  dAct := (AU - ActClamped) / TauConv;

  { Fiber kinematics }
  L := FMuscle.Lopt + FMuscle.R_ma * (ATheta - FMuscle.ThetaOpt);
  if L < 0.01 then
    L := 0.01;
  V := FMuscle.R_ma * AOmega;

  { Force-length relation }
  Fl := Exp(-Sqr((L / FMuscle.Lopt - 1.0) / 0.56));

  { Hill Force-velocity relation: concentric V <= 0, eccentric V > 0 }
  if V <= 0.0 then
  begin
    VNorm := -V / FMuscle.Vmax;
    if VNorm >= 1.0 then
      Fv := 0.0
    else
      Fv := (1.0 - VNorm) / (1.0 + VNorm / 0.25);
  end
  else
  begin
    Fv := 1.0 + 0.8 * (V / (V + 0.15 * FMuscle.Vmax));
  end;
  Fv := Clamp(Fv, 0.0, 1.8);

  { Forces & torques }
  Fm := ActClamped * FMuscle.Fmax * Fl * Fv;
  TauMus := FMuscle.R_ma * Fm;
  TauGrav := FAnthro.GravMomentCoeff * Cos(ATheta);

  { Passive elastic joint limit torque: resists hyperextension (<0 deg) & deep flexion (>120 deg) }
  TauElast := 3.1 * SafeExp(-22.0 * (ATheta - 0.05)) - 1.2 * SafeExp(6.0 * (ATheta - 2.0943951));
  TauDamp := -FMuscle.B_damp * AOmega;

  Alpha := (-TauMus + TauGrav + TauElast + TauDamp) / FAnthro.IKnee;

  dTheta := AOmega;
  dOmega := Alpha;

  FillChar(AOutState, SizeOf(AOutState), 0);
  AOutState.Theta := ATheta;
  AOutState.Omega := AOmega;
  AOutState.Alpha := Alpha;
  AOutState.Activation := ActClamped;
  AOutState.RecruitmentU := AU;
  AOutState.FiberLength := L;
  AOutState.FiberVel := V;
  AOutState.ForceLength := Fl;
  AOutState.ForceVelocity := Fv;
  AOutState.MuscleForce := Fm;
  AOutState.MusTorque := TauMus;
  AOutState.GravTorque := TauGrav;
  AOutState.ElastTorque := TauElast;
  AOutState.DampTorque := TauDamp;
  AOutState.NetTorque := -TauMus + TauGrav + TauElast + TauDamp;
  AOutState.F_X_t := Fm;
end;

procedure TKneeSimEngine.Reset(AInitialThetaDeg: Double; AInitialActivation: Double);
var
  dT, dOm, dA: Double;
  DummyState: TKneeState;
begin
  FillChar(FState, SizeOf(FState), 0);
  FState.Time := 0.0;
  FState.Theta := AInitialThetaDeg * DEG_TO_RAD;
  FState.Omega := 0.0;
  FState.Activation := Clamp(AInitialActivation, 0.0, 1.0);
  FState.StimS1 := 0.0;
  EvaluateAt(FState.Theta, FState.Omega, FState.Activation, 0.0, dT, dOm, dA, DummyState);
  DummyState.Time := 0.0;
  DummyState.StimS1 := 0.0;
  FState := DummyState;
end;

procedure TKneeSimEngine.Step(ADt: Double; AStimS1: Double; AFESMode: Boolean);
var
  S1Clamped, U: Double;
  Th, Om, Ac: Double;
  k1T, k1O, k1A: Double;
  k2T, k2O, k2A: Double;
  k3T, k3O, k3A: Double;
  k4T, k4O, k4A: Double;
  FinalState, TmpState: TKneeState;
  DummyDT, DummyDOm, DummyDA: Double;
begin
  if ADt <= 0.0 then
    Exit;

  if AFESMode then
  begin
    S1Clamped := Clamp(AStimS1, 0.0, 1.0);
    U := ComputeRecruitment(S1Clamped);
  end
  else
  begin
    S1Clamped := 0.0;
    U := 0.0;
  end;

  Th := FState.Theta;
  Om := FState.Omega;
  Ac := FState.Activation;

  EvaluateAt(Th, Om, Ac, U, k1T, k1O, k1A, TmpState);
  EvaluateAt(Th + 0.5 * ADt * k1T, Om + 0.5 * ADt * k1O, Ac + 0.5 * ADt * k1A, U,
    k2T, k2O, k2A, TmpState);
  EvaluateAt(Th + 0.5 * ADt * k2T, Om + 0.5 * ADt * k2O, Ac + 0.5 * ADt * k2A, U,
    k3T, k3O, k3A, TmpState);
  EvaluateAt(Th + ADt * k3T, Om + ADt * k3O, Ac + ADt * k3A, U,
    k4T, k4O, k4A, TmpState);

  Th := Th + (ADt / 6.0) * (k1T + 2.0 * k2T + 2.0 * k3T + k4T);
  Om := Om + (ADt / 6.0) * (k1O + 2.0 * k2O + 2.0 * k3O + k4O);
  Ac := Clamp(Ac + (ADt / 6.0) * (k1A + 2.0 * k2A + 2.0 * k3A + k4A), 0.0, 1.0);

  EvaluateAt(Th, Om, Ac, U, DummyDT, DummyDOm, DummyDA, FinalState);
  FinalState.Time := FState.Time + ADt;
  FinalState.StimS1 := S1Clamped;
  FState := FinalState;
end;

end.
