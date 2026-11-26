program test_biomech;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

uses
  SysUtils, Math,
  uBiomechCore;

var
  PassCount: Integer = 0;
  FailCount: Integer = 0;

procedure AssertTrue(const AName: string; ACondition: Boolean);
begin
  if ACondition then
  begin
    Inc(PassCount);
    WriteLn('[PASS] ', AName);
  end
  else
  begin
    Inc(FailCount);
    WriteLn('[FAIL] ', AName);
  end;
end;

procedure AssertNear(const AName: string; AActual, AExpected, ATol: Double);
begin
  if (not IsNan(AActual)) and (not IsInfinite(AActual)) and
     (Abs(AActual - AExpected) <= ATol) then
  begin
    Inc(PassCount);
    WriteLn(Format('[PASS] %s (actual=%.6f, expected=%.6f)', [AName, AActual, AExpected]));
  end
  else
  begin
    Inc(FailCount);
    WriteLn(Format('[FAIL] %s (actual=%.6f, expected=%.6f, tol=%.6f)',
      [AName, AActual, AExpected, ATol]));
  end;
end;

procedure TestAnthropometry;
var
  A: TAnthropometricData;
begin
  WriteLn('--- Testing Winter (2009) Anthropometry (70 kg, 1.75 m) ---');
  A := ComputeAnthropometry(70.0, 1.75);
  AssertNear('L1 = 0.245 * 1.75', A.L1, 0.245 * 1.75, 1e-9);
  AssertNear('M1 = 0.100 * 70', A.M1, 7.0, 1e-9);
  AssertNear('A1 = 0.433 * L1', A.A1, 0.433 * A.L1, 1e-9);
  AssertNear('I1 = M1 * sqr(0.323 * L1)', A.I1, A.M1 * Sqr(0.323 * A.L1), 1e-9);

  AssertNear('L2 = 0.246 * 1.75', A.L2, 0.246 * 1.75, 1e-9);
  AssertNear('M2 = 0.0465 * 70', A.M2, 0.0465 * 70.0, 1e-9);
  AssertNear('A2 = 0.433 * L2', A.A2, 0.433 * A.L2, 1e-9);
  AssertNear('I2 = M2 * sqr(0.302 * L2)', A.I2, A.M2 * Sqr(0.302 * A.L2), 1e-9);

  AssertNear('L3 = 0.152 * 1.75', A.L3, 0.152 * 1.75, 1e-9);
  AssertNear('M3 = 0.0145 * 70', A.M3, 0.0145 * 70.0, 1e-9);
  AssertNear('A3 = 0.500 * L3', A.A3, 0.500 * A.L3, 1e-9);
  AssertNear('I3 = M3 * sqr(0.475 * L3)', A.I3, A.M3 * Sqr(0.475 * A.L3), 1e-9);

  AssertTrue('IKnee > 0', A.IKnee > 0.0);
  AssertTrue('GravMomentCoeff > 0', A.GravMomentCoeff > 0.0);
end;

procedure TestRecruitmentAndActivation;
var
  Eng: TKneeSimEngine;
  U0, U05, U1: Double;
  I: Integer;
  TargetRise, TargetFall: Double;
begin
  WriteLn('--- Testing Recruitment Curve & Activation Dynamics ---');
  Eng := TKneeSimEngine.Create(70.0, 1.75);
  try
    U0 := Eng.ComputeRecruitment(0.0);
    U05 := Eng.ComputeRecruitment(0.5);
    U1 := Eng.ComputeRecruitment(1.0);

    AssertNear('Recruitment s1=0.0', U0, 0.5 * Tanh(-7.5) + 0.5, 1e-9);
    AssertNear('Recruitment s1=0.5', U05, 0.5, 1e-9);
    AssertNear('Recruitment s1=1.0', U1, 0.5 * Tanh(7.5) + 0.5, 1e-9);

    { Activation rise constant Tr = 0.100 s -> after 100 steps of 0.001 s at u~1, a ~ 1 - exp(-1) = 0.63212 }
    Eng.Reset(90.0, 0.0);
    for I := 1 to 100 do
      Eng.Step(0.001, 1.0, True);
    TargetRise := U1 * (1.0 - Exp(-0.100 / 0.100));
    AssertNear('Activation rise at t=Tr=0.100s', Eng.State.Activation, TargetRise, 0.002);

    { Activation fall constant Tf = 0.150 s -> starting from a=1.0, after 150 steps of 0.001 s at u=0, a ~ exp(-1) = 0.36788 }
    Eng.Reset(90.0, 1.0);
    for I := 1 to 150 do
      Eng.Step(0.001, 0.0, False);
    TargetFall := Exp(-0.150 / 0.150);
    AssertNear('Activation fall at t=Tf=0.150s', Eng.State.Activation, TargetFall, 0.002);
  finally
    Eng.Free;
  end;
end;

procedure TestLagrange3DOF;
var
  A: TAnthropometricData;
  Theta, Omega, ThetaPlus, ThetaMinus: TVector3;
  R, RPlus, RMinus: TLagrange3DOFResult;
  Mdot, Skew: TMatrix3x3;
  Det, Eps, MaxSkewErr: Double;
  I, J: Integer;
begin
  WriteLn('--- Testing 3-DOF Lagrangian Matrices ---');
  A := ComputeAnthropometry(70.0, 1.75);
  Theta[0] := 1.2;
  Theta[1] := 0.8;
  Theta[2] := -0.3;
  Omega[0] := 0.5;
  Omega[1] := -1.2;
  Omega[2] := 0.4;

  R := EvaluateLagrange3DOF(A, Theta, Omega);

  AssertNear('M[0,1] = M[1,0]', R.M[0, 1], R.M[1, 0], 1e-12);
  AssertNear('M[0,2] = M[2,0]', R.M[0, 2], R.M[2, 0], 1e-12);
  AssertNear('M[1,2] = M[2,1]', R.M[1, 2], R.M[2, 1], 1e-12);

  AssertTrue('M[0,0] > 0', R.M[0, 0] > 0.0);
  AssertTrue('M[1,1] > 0', R.M[1, 1] > 0.0);
  AssertTrue('M[2,2] > 0', R.M[2, 2] > 0.0);

  Det := R.M[0, 0] * (R.M[1, 1] * R.M[2, 2] - R.M[1, 2] * R.M[2, 1])
       - R.M[0, 1] * (R.M[1, 0] * R.M[2, 2] - R.M[1, 2] * R.M[2, 0])
       + R.M[0, 2] * (R.M[1, 0] * R.M[2, 1] - R.M[1, 1] * R.M[2, 0]);
  AssertTrue('Det(M) > 0 (positive definite)', Det > 0.0);

  { Verify skew-symmetry of (Mdot - 2*C) via central finite difference along Omega }
  Eps := 1e-6;
  for I := 0 to 2 do
  begin
    ThetaPlus[I] := Theta[I] + Eps * Omega[I];
    ThetaMinus[I] := Theta[I] - Eps * Omega[I];
  end;
  RPlus := EvaluateLagrange3DOF(A, ThetaPlus, Omega);
  RMinus := EvaluateLagrange3DOF(A, ThetaMinus, Omega);

  MaxSkewErr := 0.0;
  for I := 0 to 2 do
    for J := 0 to 2 do
    begin
      Mdot[I, J] := (RPlus.M[I, J] - RMinus.M[I, J]) / (2.0 * Eps);
      Skew[I, J] := Mdot[I, J] - 2.0 * R.C[I, J];
    end;

  for I := 0 to 2 do
    for J := 0 to 2 do
      if Abs(Skew[I, J] + Skew[J, I]) > MaxSkewErr then
        MaxSkewErr := Abs(Skew[I, J] + Skew[J, I]);

  AssertNear('Skew-symmetry max|(Mdot-2C) + (Mdot-2C)^T|', MaxSkewErr, 0.0, 1e-9);

  AssertTrue('TauP1, TauP2, TauP3 finite',
    (not IsNan(R.TauP1)) and (not IsNan(R.TauP2)) and (not IsNan(R.TauP3)));
end;

procedure TestFESKneeExtension;
var
  Eng: TKneeSimEngine;
  I: Integer;
  MinThetaDeg, FinalThetaDeg: Double;
  AllFinite: Boolean;
begin
  WriteLn('--- Testing 1-DOF FES Knee Extension Simulation ---');
  Eng := TKneeSimEngine.Create(70.0, 1.75);
  try
    Eng.Reset(90.0, 0.0);
    MinThetaDeg := 90.0;
    AllFinite := True;

    for I := 1 to 2000 do
    begin
      Eng.Step(0.001, 1.0, True);
      if IsNan(Eng.State.Theta) or IsInfinite(Eng.State.Theta) or
         IsNan(Eng.State.Omega) or IsInfinite(Eng.State.Omega) or
         IsNan(Eng.State.MusTorque) or IsInfinite(Eng.State.MusTorque) then
      begin
        AllFinite := False;
        Break;
      end;
      if Eng.State.Theta * RAD_TO_DEG < MinThetaDeg then
        MinThetaDeg := Eng.State.Theta * RAD_TO_DEG;
    end;

    FinalThetaDeg := Eng.State.Theta * RAD_TO_DEG;
    WriteLn(Format('    MinTheta=%.2f deg, FinalTheta=%.2f deg, FinalOmega=%.2f deg/s, MusTorque=%.2f Nm',
      [MinThetaDeg, FinalThetaDeg, Eng.State.Omega * RAD_TO_DEG, Eng.State.MusTorque]));

    AssertTrue('No NaN/Inf during 2.0s FES simulation', AllFinite);
    AssertTrue('Knee extends below 60 deg (MinTheta < 60 deg)', MinThetaDeg < 60.0);
    AssertTrue('Knee settles stably without hyperextension explosion (FinalTheta in [-10, 60] deg)',
      (FinalThetaDeg >= -10.0) and (FinalThetaDeg < 60.0));
  finally
    Eng.Free;
  end;
end;

begin
  TestAnthropometry;
  TestRecruitmentAndActivation;
  TestLagrange3DOF;
  TestFESKneeExtension;

  WriteLn(Format('Summary: %d passed, %d failed', [PassCount, FailCount]));
  if FailCount > 0 then
    Halt(1);
end.
