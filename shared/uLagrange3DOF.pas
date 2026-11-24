unit uLagrange3DOF;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  uBiomechTypes;

{ Evaluates the 3-DOF planar lower-limb Lagrangian matrices M(theta), C(theta, omega),
  G(theta), and passive viscoelastic joint torques (Riener & Edrich 1999 style).
  Theta/Omega indices: [0]=Hip, [1]=Knee, [2]=Ankle (rad, rad/s). }
function EvaluateLagrange3DOF(const Anthro: TAnthropometricData;
  const Theta, Omega: TVector3): TLagrange3DOFResult;

implementation

uses
  Math;

function SafeExp(AX: Double): Double;
begin
  if AX > 40.0 then
    AX := 40.0
  else if AX < -40.0 then
    AX := -40.0;
  Result := Exp(AX);
end;

function EvalDoubleExpPassive(ATheta, AOmega, AK1, AK2, AThetaMin,
  AK3, AK4, AThetaMax, ADamp: Double): Double;
begin
  { Restoring viscoelastic torque resisting limits + linear viscous damping }
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
  dM: array[0..2, 0..2, 0..2] of Double; { dM[k, i, j] = d(M[i,j])/d(Theta[k]) }
  I, J, K: Integer;
  SumC: Double;
begin
  { Lumped inertial parameters for 3-link serial planar chain }
  P1 := Anthro.I1 + Anthro.M1 * Sqr(Anthro.A1) + (Anthro.M2 + Anthro.M3) * Sqr(Anthro.L1);
  P2 := Anthro.I2 + Anthro.M2 * Sqr(Anthro.A2) + Anthro.M3 * Sqr(Anthro.L2);
  P3 := Anthro.I3 + Anthro.M3 * Sqr(Anthro.A3);

  D1 := (Anthro.M2 * Anthro.A2 + Anthro.M3 * Anthro.L2) * Anthro.L1;
  D2 := Anthro.M3 * Anthro.L1 * Anthro.A3;
  D3 := Anthro.M3 * Anthro.L2 * Anthro.A3;

  C2 := Cos(Theta[1]);
  C3 := Cos(Theta[2]);
  C23 := Cos(Theta[1] + Theta[2]);
  S2 := Sin(Theta[1]);
  S3 := Sin(Theta[2]);
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

  { Partial derivatives dM[k, i, j] = d(M[i,j])/d(Theta[k]) for Christoffel symbols }
  for K := 0 to 2 do
    for I := 0 to 2 do
      for J := 0 to 2 do
        dM[K, I, J] := 0.0;

  { k = 1 (Theta[1] = knee relative angle) }
  dM[1, 0, 0] := -2.0 * D1 * S2 - 2.0 * D2 * S23;
  dM[1, 0, 1] := -D1 * S2 - D2 * S23;
  dM[1, 1, 0] := dM[1, 0, 1];
  dM[1, 0, 2] := -D2 * S23;
  dM[1, 2, 0] := dM[1, 0, 2];

  { k = 2 (Theta[2] = ankle relative angle) }
  dM[2, 0, 0] := -2.0 * D2 * S23 - 2.0 * D3 * S3;
  dM[2, 0, 1] := -D2 * S23 - 2.0 * D3 * S3;
  dM[2, 1, 0] := dM[2, 0, 1];
  dM[2, 0, 2] := -D2 * S23 - D3 * S3;
  dM[2, 2, 0] := dM[2, 0, 2];
  dM[2, 1, 1] := -2.0 * D3 * S3;
  dM[2, 1, 2] := -D3 * S3;
  dM[2, 2, 1] := dM[2, 1, 2];

  { Coriolis/centrifugal matrix C(theta, omega) via Christoffel symbols of the first kind }
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

  { Gravity vector G(theta) = dV/dTheta (angles measured from downward vertical) }
  Phi1 := Theta[0];
  Phi2 := Theta[0] + Theta[1];
  Phi3 := Theta[0] + Theta[1] + Theta[2];

  G1 := (Anthro.M1 * Anthro.A1 + (Anthro.M2 + Anthro.M3) * Anthro.L1) * GRAVITY;
  G2 := (Anthro.M2 * Anthro.A2 + Anthro.M3 * Anthro.L2) * GRAVITY;
  G3 := Anthro.M3 * Anthro.A3 * GRAVITY;

  Result.G[0] := G1 * Sin(Phi1) + G2 * Sin(Phi2) + G3 * Sin(Phi3);
  Result.G[1] := G2 * Sin(Phi2) + G3 * Sin(Phi3);
  Result.G[2] := G3 * Sin(Phi3);

  { Passive viscoelastic joint torques (Riener & Edrich 1999 double-exponential + damping) }
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

end.
