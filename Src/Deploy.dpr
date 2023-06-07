program Deploy;

{$APPTYPE CONSOLE}

{$R *.res}
{$R *.dres}


uses
  Winapi.Windows,
  System.DateUtils,
  System.SysUtils,
  System.IOUtils,
  ServiceConsole in 'Service\ServiceConsole.pas',
  ServiceExtract in 'Service\ServiceExtract.pas',
  ServiceStripReloc in 'Service\ServiceStripReloc.pas',
  ServiceAssociation in 'Service\ServiceAssociation.pas',
  ServiceDeploy in 'Service\ServiceDeploy.pas';

begin
  try
    ServiceDeploy.Deploy.Execute;
  except
    on E: Exception do
    begin
      head(ccRed);
      line('Deployment program returned exception below', ccRed);
      rows(ccRed);
      line(E.Message, ccRed, ' • ');
      rowe(ccRed);
    end;
  end;

end.
