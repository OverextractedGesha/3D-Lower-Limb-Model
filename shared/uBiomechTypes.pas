unit uBiomechTypes;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

const
  GRAVITY = 9.81;        { m/s^2 }
  DEFAULT_BW = 70.0;     { kg }
  DEFAULT_BH = 1.75;     { m }
  RAD_TO_DEG = 180.0 / Pi;
  DEG_TO_RAD = Pi / 180.0;

type
  TVector3 = array[0..2] of Double;
  TMatrix3x3 = array[0..2, 0..2] of Double;

  TAnthropometricData = record
    BW: Double;              { Body weight (kg) }
    BH: Double;              { Body height (m) }
    L1, M1, A1, I1: Double;  { Thigh: length (m), mass (kg), COM from proximal (m), inertia (kg*m^2) }
    L2, M2, A2, I2: Double;  { Shank: length (m), mass (kg), COM from proximal (m), inertia (kg*m^2) }
    L3, M3, A3, I3: Double;  { Foot:  length (m), mass (kg), COM from proximal (m), inertia (kg*m^2) }
    IKnee: Double;           { Combined seated knee-extension moment of inertia (kg*m^2) }
    GravMomentCoeff: Double; { Effective gravity moment arm * g (N*m) }
  end;

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

  TKneeState = record
    Time: Double;          { Simulation time (s) }
    Theta: Double;         { Knee flexion angle (rad): Pi/2 = hanging 90 deg, 0 = horizontal extension }
    Omega: Double;         { Knee angular velocity (rad/s) }
    Alpha: Double;         { Knee angular acceleration (rad/s^2) }
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
    ElastTorque: Double;   { Passive elastic torque TauElast (N*m) }
    DampTorque: Double;    { Passive damping torque TauDamp (N*m) }
    NetTorque: Double;     { Net torque on knee joint (N*m) }
    F_X_t: Double;         { Active muscle force F(X(t)) = Fm = a * Fmax * f(l) * f(v) (N) }
  end;

  TLagrange3DOFResult = record
    M: TMatrix3x3;         { 3x3 symmetric positive-definite inertia matrix }
    C: TMatrix3x3;         { 3x3 Coriolis/centrifugal matrix }
    G: TVector3;           { 3x1 gravity torque vector [Hip, Knee, Ankle] }
    TauPassive: TVector3;  { 3x1 passive viscoelastic torques [Hip(TauP3), Knee(TauP2), Ankle(TauP1)] }
    TauP1: Double;         { Ankle passive torque (N*m) }
    TauP2: Double;         { Knee passive torque (N*m) }
    TauP3: Double;         { Hip passive torque (N*m) }
  end;

implementation

end.
