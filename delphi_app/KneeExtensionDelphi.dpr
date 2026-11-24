program KneeExtensionDelphi;

uses
  Vcl.Forms,
  uBiomechTypes in '..\shared\uBiomechTypes.pas',
  uAnthropometry in '..\shared\uAnthropometry.pas',
  uLagrange3DOF in '..\shared\uLagrange3DOF.pas',
  uKneeSimEngine in '..\shared\uKneeSimEngine.pas',
  uMainFormDelphi in 'uMainFormDelphi.pas' {MainFormDelphi},
  uModelFormDelphi in 'uModelFormDelphi.pas' {ModelFormDelphi};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMainFormDelphi, MainFormDelphi);
  Application.Run;
end.
