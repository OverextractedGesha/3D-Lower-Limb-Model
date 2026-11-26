unit uBiomechCore;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

{ Physical Constants & Data Structures }

const
  GRAVITY    = 9.81;        { Gravitational acceleration g (m/s^2) }
  DEFAULT_BW = 70.0;        { Default body weight (kg) }
  DEFAULT_BH = 1.75;        { Default body height (m) }
  RAD_TO_DEG = 180.0 / Pi;
  DEG_TO_RAD = Pi / 180.0;

type
  TVector3   = array[0..2] of Double;          { 3x1 vector: [0]=Hip, [1]=Knee, [2]=Ankle }
  TMatrix3x3 = array[0..2, 0..2] of Double;    { 3x3 matrix for 3-DOF dynamics }

  { Segmental body parameters from Winter (2009) }
  TAnthropometricData = record
    BW: Double;              { Body weight (kg) }
    BH: Double;              { Body height (m) }
    L1, M1, A1, I1: Double;  { Thigh: length (m), mass (kg), COM from proximal (m), inertia (kg*m^2) }
    L2, M2, A2, I2: Double;  { Shank: length (m), mass (kg), COM from proximal (m), inertia (kg*m^2) }
    L3, M3, A3, I3: Double;  { Foot:  length (m), mass (kg), COM from proximal (m), inertia (kg*m^2) }
    IKnee: Double;           { Combined seated knee-extension moment of inertia (kg*m^2) }
    GravMomentCoeff: Double; { Effective gravity torque coefficient (N*m) }
  end;

  { Hill-type quadriceps muscle parameters }
  TMuscleParams = record
    Fmax: Double;     { Maximum isometric muscle force (N) }
    Lopt: Double;     { Optimal muscle fiber length (m) }
    R_ma: Double;     { Effective patellar tendon moment arm (m) }
    ThetaOpt: Double; { Knee angle at optimal fiber length (rad) }
    Vmax: Double;     { Maximum contraction velocity (m/s) }
    Tr: Double;       { Activation rise time constant (s) }
    Tf: Double;       { Activation fall time constant (s) }
    B_damp: Double;   { Passive viscous damping coefficient (N*m*s/rad) }
  end;

  { Snapshot of all 1-DOF knee simulation variables at time t }
  TKneeState = record
    Time: Double;          { Simulation time t (s) }
    Theta: Double;         { Knee flexion angle (rad): Pi/2 = 90 deg hanging, 0 = horizontal extension }
    Omega: Double;         { Knee angular velocity d(Theta)/dt (rad/s) }
    Alpha: Double;         { Knee angular acceleration d^2(Theta)/dt^2 (rad/s^2) }
    Activation: Double;    { Muscle activation a in [0, 1] }
    StimS1: Double;        { FES stimulation intensity s1 in [0, 1] }
    RecruitmentU: Double;  { Neural recruitment u in [0, 1] }
    FiberLength: Double;   { Muscle fiber length L (m) }
    FiberVel: Double;      { Muscle fiber velocity V (m/s) }
    ForceLength: Double;   { Normalized force-length factor f(l) }
    ForceVelocity: Double; { Normalized force-velocity factor f(v) }
    MuscleForce: Double;   { Active muscle force Fm (N) }
    MusTorque: Double;     { Active muscle torque TauMus (N*m) }
    GravTorque: Double;    { Gravitational torque TauGrav (N*m) }
    ElastTorque: Double;   { Passive elastic limit torque TauElast (N*m) }
    DampTorque: Double;    { Passive viscous damping torque TauDamp (N*m) }
    NetTorque: Double;     { Net torque on knee joint (N*m) }
    F_X_t: Double;         { Alias for active muscle force F(X(t)) = Fm (N) }
  end;

  { Output of 3-DOF Lagrangian model: M(q)*qdd + C(q,qd)*qd + G(q) = TauAct + TauPassive }
  TLagrange3DOFResult = record
    M: TMatrix3x3;         { 3x3 symmetric positive-definite inertia matrix }
    C: TMatrix3x3;         { 3x3 Coriolis/centrifugal matrix (via Christoffel symbols) }
    G: TVector3;           { 3x1 gravity torque vector [Hip, Knee, Ankle] }
    TauPassive: TVector3;  { 3x1 passive viscoelastic torques [Hip(TauP3), Knee(TauP2), Ankle(TauP1)] }
    TauP1: Double;         { Ankle passive torque (N*m) }
    TauP2: Double;         { Knee passive torque (N*m) }
    TauP3: Double;         { Hip passive torque (N*m) }
  end;

  { 1-DOF FES Knee Extension Simulator }
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

{ Winter (2009) segmental anthropometric parameters & seated knee constants }
function ComputeAnthropometry(ABW, ABH: Double): TAnthropometricData;

{ 3-DOF planar lower-limb Euler-Lagrange matrices M, C, G & passive torques }
function EvaluateLagrange3DOF(const Anthro: TAnthropometricData;
  const Theta, Omega: TVector3): TLagrange3DOFResult;

implementation

{ From-Scratch Math Helpers (No External Library) }

{ Bounds a value to [AMin, AMax] }
function Clamp(AVal, AMin, AMax: Double): Double;
begin
  if AVal < AMin then
    Result := AMin
  else if AVal > AMax then
    Result := AMax
  else
    Result := AVal;
end;

{ Overflow-safe exponential: clamps exponent to [-40, 40] before Exp() }
function SafeExp(AX: Double): Double;
begin
  Result := Exp(Clamp(AX, -40.0, 40.0));
end;

{ From-scratch hyperbolic tangent: tanh(x) = (e^(2x) - 1) / (e^(2x) + 1) }
function SafeTanh(AX: Double): Double;
var
  E2X: Double;
begin
  if AX > 20.0 then
    Result := 1.0
  else if AX < -20.0 then
    Result := -1.0
  else
  begin
    E2X := Exp(2.0 * AX);
    Result := (E2X - 1.0) / (E2X + 1.0);
  end;
end;

{ Winter (2009) Segmental Anthropometry
  Computes segment length L, mass M, proximal COM A, and moment of inertia I
  from Body Weight (BW, kg) and Body Height (BH, m). }

function ComputeAnthropometry(ABW, ABH: Double): TAnthropometricData;
begin
  if ABW <= 0.0 then
    ABW := DEFAULT_BW;
  if ABH <= 0.0 then
    ABH := DEFAULT_BH;

  Result.BW := ABW;
  Result.BH := ABH;

  { Segment 1 — Thigh: L1=0.245*BH, M1=0.100*BW, A1=0.433*L1, I1=M1*(0.323*L1)^2 }
  Result.L1 := 0.245 * ABH;
  Result.M1 := 0.100 * ABW;
  Result.A1 := 0.433 * Result.L1;
  Result.I1 := Result.M1 * Sqr(0.323 * Result.L1);

  { Segment 2 — Shank: L2=0.246*BH, M2=0.0465*BW, A2=0.433*L2, I2=M2*(0.302*L2)^2 }
  Result.L2 := 0.246 * ABH;
  Result.M2 := 0.0465 * ABW;
  Result.A2 := 0.433 * Result.L2;
  Result.I2 := Result.M2 * Sqr(0.302 * Result.L2);

  { Segment 3 — Foot: L3=0.152*BH, M3=0.0145*BW, A3=0.500*L3, I3=M3*(0.475*L3)^2 }
  Result.L3 := 0.152 * ABH;
  Result.M3 := 0.0145 * ABW;
  Result.A3 := 0.500 * Result.L3;
  Result.I3 := Result.M3 * Sqr(0.475 * Result.L3);

  { Seated 1-DOF knee inertia (parallel-axis theorem for shank + foot about knee) }
  Result.IKnee := Result.I2 + Result.M2 * Sqr(Result.A2) +
                  Result.I3 + Result.M3 * (Sqr(Result.L2) + Sqr(Result.A3));

  { Effective gravity torque coefficient: (M2*A2 + M3*L2) * g }
  Result.GravMomentCoeff := (Result.M2 * Result.A2 + Result.M3 * Result.L2) * GRAVITY;
end;

{ 3-DOF Planar Lower-Limb Lagrangian Dynamics
  Equation: M(theta)*theta_dd + C(theta, omega)*omega + G(theta) = TauAct + TauPassive
  Indices:  [0] = Hip, [1] = Knee, [2] = Ankle (rad, rad/s) }

{ Riener & Edrich (1999) double-exponential passive elastic torque + viscous damping }
function EvalDoubleExpPassive(ATheta, AOmega, AK1, AK2, AThetaMin,
  AK3, AK4, AThetaMax, ADamp: Double): Double;
begin
  Result := AK1 * SafeExp(-AK2 * (ATheta - AThetaMin))
          - AK3 * SafeExp(AK4 * (ATheta - AThetaMax))
          - ADamp * AOmega;
end;

function EvaluateLagrange3DOF(const Anthro: TAnthropometricData;
  const Theta, Omega: TVector3): TLagrange3DOFResult;
var
  P1, P2, P3, D1, D2, D3: Double;
  G1, G2, G3: Double;
  Phi1, Phi2, Phi3: Double;
  C2, C3, C23, S2, S3, S23: Double;
  dM: array[0..2, 0..2, 0..2] of Double; { Partial derivatives: dM[k,i,j] = d(M[i,j])/d(Theta[k]) }
  I, J, K: Integer;
  SumC: Double;
begin
  { Lumped inertial & coupling constants for 3-link serial chain }
  P1 := Anthro.I1 + Anthro.M1 * Sqr(Anthro.A1) + (Anthro.M2 + Anthro.M3) * Sqr(Anthro.L1);
  P2 := Anthro.I2 + Anthro.M2 * Sqr(Anthro.A2) + Anthro.M3 * Sqr(Anthro.L2);
  P3 := Anthro.I3 + Anthro.M3 * Sqr(Anthro.A3);

  D1 := (Anthro.M2 * Anthro.A2 + Anthro.M3 * Anthro.L2) * Anthro.L1;
  D2 := Anthro.M3 * Anthro.L1 * Anthro.A3;
  D3 := Anthro.M3 * Anthro.L2 * Anthro.A3;

  C2  := Cos(Theta[1]);
  C3  := Cos(Theta[2]);
  C23 := Cos(Theta[1] + Theta[2]);
  S2  := Sin(Theta[1]);
  S3  := Sin(Theta[2]);
  S23 := Sin(Theta[1] + Theta[2]);

  { Symmetric 3x3 Inertia Matrix M(theta) }
  Result.M[0, 0] := P1 + P2 + P3 + 2.0 * D1 * C2 + 2.0 * D2 * C23 + 2.0 * D3 * C3;
  Result.M[0, 1] := P2 + P3 + D1 * C2 + D2 * C23 + 2.0 * D3 * C3;
  Result.M[0, 2] := P3 + D2 * C23 + D3 * C3;

  Result.M[1, 0] := Result.M[0, 1];
  Result.M[1, 1] := P2 + P3 + 2.0 * D3 * C3;
  Result.M[1, 2] := P3 + D3 * C3;

  Result.M[2, 0] := Result.M[0, 2];
  Result.M[2, 1] := Result.M[1, 2];
  Result.M[2, 2] := P3;

  { Analytic partial derivatives dM[k, i, j] = d(M[i,j]) / d(Theta[k]) }
  for K := 0 to 2 do
    for I := 0 to 2 do
      for J := 0 to 2 do
        dM[K, I, J] := 0.0;

  { Derivatives w.r.t. knee angle Theta[1] (k = 1) }
  dM[1, 0, 0] := -2.0 * D1 * S2 - 2.0 * D2 * S23;
  dM[1, 0, 1] := -D1 * S2 - D2 * S23;
  dM[1, 1, 0] := dM[1, 0, 1];
  dM[1, 0, 2] := -D2 * S23;
  dM[1, 2, 0] := dM[1, 0, 2];

  { Derivatives w.r.t. ankle angle Theta[2] (k = 2) }
  dM[2, 0, 0] := -2.0 * D2 * S23 - 2.0 * D3 * S3;
  dM[2, 0, 1] := -D2 * S23 - 2.0 * D3 * S3;
  dM[2, 1, 0] := dM[2, 0, 1];
  dM[2, 0, 2] := -D2 * S23 - D3 * S3;
  dM[2, 2, 0] := dM[2, 0, 2];
  dM[2, 1, 1] := -2.0 * D3 * S3;
  dM[2, 1, 2] := -D3 * S3;
  dM[2, 2, 1] := dM[2, 1, 2];

  { Coriolis/Centrifugal Matrix C(theta, omega) via Christoffel Symbols }
  { C[i,j] = sum_k 0.5 * (dM[k,i,j] + dM[j,i,k] - dM[i,j,k]) * omega[k] }
  for I := 0 to 2 do
  begin
    for J := 0 to 2 do
    begin
      SumC := 0.0;
      for K := 0 to 2 do
        SumC := SumC + 0.5 * (dM[K, I, J] + dM[J, I, K] - dM[I, J, K]) * Omega[K];
      Result.C[I, J] := SumC;
    end;
  end;

  { Gravity Torque Vector G(theta) = dV / dTheta }
  Phi1 := Theta[0];
  Phi2 := Theta[0] + Theta[1];
  Phi3 := Theta[0] + Theta[1] + Theta[2];

  G1 := (Anthro.M1 * Anthro.A1 + (Anthro.M2 + Anthro.M3) * Anthro.L1) * GRAVITY;
  G2 := (Anthro.M2 * Anthro.A2 + Anthro.M3 * Anthro.L2) * GRAVITY;
  G3 := Anthro.M3 * Anthro.A3 * GRAVITY;

  Result.G[0] := G1 * Sin(Phi1) + G2 * Sin(Phi2) + G3 * Sin(Phi3);
  Result.G[1] := G2 * Sin(Phi2) + G3 * Sin(Phi3);
  Result.G[2] := G3 * Sin(Phi3);

  { Passive Viscoelastic Joint Torques (Riener & Edrich 1999) }
  { Hip passive torque TauP3 (DOF 0) }
  Result.TauP3 := EvalDoubleExpPassive(Theta[0], Omega[0],
    2.6, 5.8, -0.35, 8.7, 5.2, 2.09, 1.5);
  { Knee passive torque TauP2 (DOF 1) }
  Result.TauP2 := EvalDoubleExpPassive(Theta[1], Omega[1],
    3.1, 5.9, 0.0, 1.2, 4.8, 2.18, 1.5);
  { Ankle passive torque TauP1 (DOF 2) }
  Result.TauP1 := EvalDoubleExpPassive(Theta[2], Omega[2],
    2.0, 5.5, -0.52, 4.5, 5.0, 0.35, 1.0);

  Result.TauPassive[0] := Result.TauP3;
  Result.TauPassive[1] := Result.TauP2;
  Result.TauPassive[2] := Result.TauP1;
end;

{ 1-DOF FES Knee Extension Engine (Hill Muscle + RK4 Solver)
  State vector: y = [Theta, Omega, Activation]
  Angle convention: Theta = 90 deg (Pi/2) hanging, 0 deg horizontal extension. }

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

{ Default Hill Quadriceps Muscle Parameters }
procedure TKneeSimEngine.InitDefaultMuscle;
begin
  FMuscle.Fmax     := 5000.0;        { Max isometric force (N) }
  FMuscle.Lopt     := 0.09;          { Optimal fiber length (m) }
  FMuscle.R_ma     := 0.048;         { Patellar tendon moment arm (m) }
  FMuscle.ThetaOpt := Pi / 2.0;      { Optimal angle = 90 deg hanging }
  FMuscle.Vmax     := 10.0 * FMuscle.Lopt;
  FMuscle.Tr       := 0.100;         { Activation rise time constant = 100 ms }
  FMuscle.Tf       := 0.150;         { Activation fall time constant = 150 ms }
  FMuscle.B_damp   := 1.5;           { Viscous damping (N*m*s/rad) }
end;

procedure TKneeSimEngine.SetAnthropometry(ABW, ABH: Double);
begin
  FAnthro := ComputeAnthropometry(ABW, ABH);
end;

{ FES Neural Recruitment Sigmoid: u(s1) = 0.5*tanh(15*(s1 - 0.5)) + 0.5 }
function TKneeSimEngine.ComputeRecruitment(AS1: Double): Double;
var
  S1Clamped: Double;
begin
  S1Clamped := Clamp(AS1, 0.0, 1.0);
  Result := 0.5 * SafeTanh(15.0 * (S1Clamped - 0.5)) + 0.5;
end;

{ ODE Right-Hand Side: computes [dTheta/dt, dOmega/dt, dAct/dt] }
procedure TKneeSimEngine.EvaluateAt(ATheta, AOmega, AAct, AU: Double;
  out dTheta, dOmega, dAct: Double; out AOutState: TKneeState);
var
  ActClamped, TauConv, L, V, Fl, Fv, VNorm: Double;
  Fm, TauMus, TauGrav, TauElast, TauDamp, Alpha: Double;
begin
  ActClamped := Clamp(AAct, 0.0, 1.0);

  { (a) First-order muscle activation dynamics: da/dt = (u - a) / Tau }
  if AU > ActClamped then
    TauConv := FMuscle.Tr   { Rising activation }
  else
    TauConv := FMuscle.Tf;  { Falling relaxation }
  dAct := (AU - ActClamped) / TauConv;

  { (b) Muscle fiber kinematics from joint angle & angular velocity }
  L := FMuscle.Lopt + FMuscle.R_ma * (ATheta - FMuscle.ThetaOpt);
  if L < 0.01 then
    L := 0.01;
  V := FMuscle.R_ma * AOmega;

  { (c) Gaussian Force-Length curve: f(l) = exp(-((L/Lopt - 1) / 0.56)^2) }
  Fl := Exp(-Sqr((L / FMuscle.Lopt - 1.0) / 0.56));

  { (d) Hill Force-Velocity curve: concentric (V <= 0) vs eccentric (V > 0) }
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

  { (e) Active muscle force & joint torques }
  Fm       := ActClamped * FMuscle.Fmax * Fl * Fv;
  TauMus   := FMuscle.R_ma * Fm;
  TauGrav  := FAnthro.GravMomentCoeff * Cos(ATheta);

  { Passive elastic limit torque: resists hyperextension (<0 deg) & deep flexion (>120 deg) }
  TauElast := 3.1 * SafeExp(-22.0 * (ATheta - 0.05)) - 1.2 * SafeExp(6.0 * (ATheta - 2.0943951));
  TauDamp  := -FMuscle.B_damp * AOmega;

  { (f) Knee Equation of Motion: Alpha = (-TauMus + TauGrav + TauElast + TauDamp) / IKnee }
  Alpha := (-TauMus + TauGrav + TauElast + TauDamp) / FAnthro.IKnee;

  dTheta := AOmega;
  dOmega := Alpha;

  { Store all diagnostics for UI & plotting }
  FillChar(AOutState, SizeOf(AOutState), 0);
  AOutState.Theta         := ATheta;
  AOutState.Omega         := AOmega;
  AOutState.Alpha         := Alpha;
  AOutState.Activation    := ActClamped;
  AOutState.RecruitmentU  := AU;
  AOutState.FiberLength   := L;
  AOutState.FiberVel      := V;
  AOutState.ForceLength   := Fl;
  AOutState.ForceVelocity := Fv;
  AOutState.MuscleForce   := Fm;
  AOutState.MusTorque     := TauMus;
  AOutState.GravTorque    := TauGrav;
  AOutState.ElastTorque   := TauElast;
  AOutState.DampTorque    := TauDamp;
  AOutState.NetTorque     := -TauMus + TauGrav + TauElast + TauDamp;
  AOutState.F_X_t         := Fm;
end;

procedure TKneeSimEngine.Reset(AInitialThetaDeg: Double; AInitialActivation: Double);
var
  dT, dOm, dA: Double;
  DummyState: TKneeState;
begin
  FillChar(FState, SizeOf(FState), 0);
  FState.Time       := 0.0;
  FState.Theta      := AInitialThetaDeg * DEG_TO_RAD;
  FState.Omega      := 0.0;
  FState.Activation := Clamp(AInitialActivation, 0.0, 1.0);
  FState.StimS1     := 0.0;
  EvaluateAt(FState.Theta, FState.Omega, FState.Activation, 0.0, dT, dOm, dA, DummyState);
  DummyState.Time   := 0.0;
  DummyState.StimS1 := 0.0;
  FState := DummyState;
end;

{ Numerical Integrator: 4th-Order Runge-Kutta (RK4) }
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

  { Stage 1 (t) }
  EvaluateAt(Th, Om, Ac, U, k1T, k1O, k1A, TmpState);
  { Stage 2 (t + dt/2 using k1) }
  EvaluateAt(Th + 0.5 * ADt * k1T, Om + 0.5 * ADt * k1O, Ac + 0.5 * ADt * k1A, U,
    k2T, k2O, k2A, TmpState);
  { Stage 3 (t + dt/2 using k2) }
  EvaluateAt(Th + 0.5 * ADt * k2T, Om + 0.5 * ADt * k2O, Ac + 0.5 * ADt * k2A, U,
    k3T, k3O, k3A, TmpState);
  { Stage 4 (t + dt using k3) }
  EvaluateAt(Th + ADt * k3T, Om + ADt * k3O, Ac + ADt * k3A, U,
    k4T, k4O, k4A, TmpState);

  { Weighted RK4 update: y(t+dt) = y(t) + (dt/6)*(k1 + 2*k2 + 2*k3 + k4) }
  Th := Th + (ADt / 6.0) * (k1T + 2.0 * k2T + 2.0 * k3T + k4T);
  Om := Om + (ADt / 6.0) * (k1O + 2.0 * k2O + 2.0 * k3O + k4O);
  Ac := Clamp(Ac + (ADt / 6.0) * (k1A + 2.0 * k2A + 2.0 * k3A + k4A), 0.0, 1.0);

  EvaluateAt(Th, Om, Ac, U, DummyDT, DummyDOm, DummyDA, FinalState);
  FinalState.Time   := FState.Time + ADt;
  FinalState.StimS1 := S1Clamped;
  FState := FinalState;
end;

end.
