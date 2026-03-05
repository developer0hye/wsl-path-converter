#define MyAppName "WSL Path Converter"
#ifndef MyAppVersion
  #define MyAppVersion "0.0.0"
#endif
#define MyAppPublisher "developer0hye"
#define MyAppURL "https://github.com/developer0hye/wsl-path-converter"
#define MyAppExeName "wsl-path-converter.exe"

[Setup]
AppId={{0F6B0F48-BA53-458C-8E84-CA04F6D3DCD8}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} v{#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}/releases/latest
DefaultDirName={localappdata}\Programs\WSL Path Converter
DefaultGroupName={#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExeName}
PrivilegesRequired=lowest
ArchitecturesInstallIn64BitMode=x64compatible
Compression=lzma
SolidCompression=yes
WizardStyle=modern
SetupIconFile=..\app-icon.ico
OutputDir=..
OutputBaseFilename=wsl-path-converter-setup
DisableProgramGroupPage=yes
CloseApplications=yes
CloseApplicationsFilter={#MyAppExeName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Files]
Source: "..\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\WSL Path Converter"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\WSL Path Converter"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch WSL Path Converter"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: files; Name: "{userstartup}\WSL Path Converter.lnk"
Type: filesandordirs; Name: "{userappdata}\WSL Path Converter"
