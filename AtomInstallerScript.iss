; Atom Windows Installer Script
; NOTE: Please Remove the Paths with yours on your PC!

#define MyAppName "Atom"
#define MyAppVersion "Release-136"
#define MyAppPublisher "GitHub, Inc."
#define MyAppURL "https://atom.io"
#define MyAppExeName "atom.exe"

[Setup]
AppId={{DBD0F8A4-45D1-482E-ABD2-BD8D46286E87}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
;AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={pf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
LicenseFile=C:\path\to\atom-windows-zip\atom-windows\Atom\LICENSE ;CHANGE YOUR PATH!
OutputBaseFilename=atom-winsetup
SetupIconFile=C:\path\to\atom-windows-zip\atom.ico ;CHANGE YOUR PATH!
Compression=lzma
SolidCompression=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked; OnlyBelowVersion: 0,6.1

[Files]
Source: "C:\path\to\atom-windows-zip\atom-windows\Atom\atom.exe"; DestDir: "{app}"; Flags: ignoreversion ;CHANGE YOUR PATH!
Source: "C:\path\to\atom-windows-zip\atom-windows\Atom\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs ;CHANGE YOUR PATH!

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:ProgramOnTheWeb,{#MyAppName}}"; Filename: "{#MyAppURL}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{commondesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: quicklaunchicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

