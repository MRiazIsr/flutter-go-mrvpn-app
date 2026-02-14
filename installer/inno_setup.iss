; MRVPN Installer Script for Inno Setup 6
; Build with: "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" inno_setup.iss

#define MyAppName "MRVPN"
#ifndef MyAppVersion
  #define MyAppVersion "0.0.0"
#endif
#define MyAppPublisher "MRVPN"
#define MyAppExeName "MRVPN.exe"
#define MyServiceExeName "MRVPN-service.exe"

[Setup]
AppId={{A7B8C9D0-E1F2-3456-7890-ABCDEF012345}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
OutputDir=..\build
OutputBaseFilename=MRVPN-Setup-{#MyAppVersion}
; SetupIconFile=assets\icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#MyAppExeName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "launchstartup"; Description: "Start MRVPN when Windows starts"; GroupDescription: "Startup:"

[Files]
; Main application files
Source: "..\dist\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

; WinTUN driver
Source: "assets\wintun.dll"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Registry]
; Auto-start with Windows (current user)
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "{#MyAppName}"; ValueData: """{app}\{#MyAppExeName}"" --minimized"; Flags: uninsdeletevalue; Tasks: launchstartup

[Run]
; Install and start the backend service
Filename: "{app}\{#MyServiceExeName}"; Parameters: "-install"; StatusMsg: "Installing MRVPN service..."; Flags: runhidden waituntilterminated
Filename: "net"; Parameters: "start MRVPN"; StatusMsg: "Starting MRVPN service..."; Flags: runhidden waituntilterminated

; Launch the app after install
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
; Stop and uninstall the backend service
Filename: "net"; Parameters: "stop MRVPN"; Flags: runhidden
Filename: "{app}\{#MyServiceExeName}"; Parameters: "-uninstall"; Flags: runhidden waituntilterminated

[Code]
// Kill running instances before uninstall
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  ResultCode: Integer;
begin
  if CurUninstallStep = usUninstall then
  begin
    Exec('taskkill', '/F /IM {#MyAppExeName}', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    Exec('taskkill', '/F /IM {#MyServiceExeName}', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    Sleep(1000);
  end;
end;
