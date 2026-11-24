unit uAnthropometry;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  uBiomechTypes;

{ Computes Winter (2009) segmental anthropometric parameters and seated knee dynamics constants. }
function ComputeAnthropometry(ABW, ABH: Double): TAnthropometricData;

implementation

function ComputeAnthropometry(ABW, ABH: Double): TAnthropometricData;
begin
  if ABW <= 0.0 then
    ABW := DEFAULT_BW;
  if ABH <= 0.0 then
    ABH := DEFAULT_BH;

  Result.BW := ABW;
  Result.BH := ABH;

  { Thigh (Segment 1) }
  Result.L1 := 0.245 * ABH;
  Result.M1 := 0.100 * ABW;
  Result.A1 := 0.433 * Result.L1;
  Result.I1 := Result.M1 * Sqr(0.323 * Result.L1);

  { Shank (Segment 2) }
  Result.L2 := 0.246 * ABH;
  Result.M2 := 0.0465 * ABW;
  Result.A2 := 0.433 * Result.L2;
  Result.I2 := Result.M2 * Sqr(0.302 * Result.L2);

  { Foot (Segment 3) }
  Result.L3 := 0.152 * ABH;
  Result.M3 := 0.0145 * ABW;
  Result.A3 := 0.500 * Result.L3;
  Result.I3 := Result.M3 * Sqr(0.475 * Result.L3);

  { Combined seated knee-extension moment of inertia & effective gravity torque coefficient }
  Result.IKnee := Result.I2 + Result.M2 * Sqr(Result.A2) +
                  Result.I3 + Result.M3 * (Sqr(Result.L2) + Sqr(Result.A3));
  Result.GravMomentCoeff := (Result.M2 * Result.A2 + Result.M3 * Result.L2) * GRAVITY;
end;

end.
