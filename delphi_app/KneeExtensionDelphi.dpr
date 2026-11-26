program KneeExtensionDelphi;

uses
  Vcl.Forms,
  uBiomechCore in '..\shared\uBiomechCore.pas',
  uMainFormDelphi in 'uMainFormDelphi.pas' {MainFormDelphi},
  uModelFormDelphi in 'uModelFormDelphi.pas' {ModelFormDelphi};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMainFormDelphi, MainFormDelphi);
  Application.Run;
end.
