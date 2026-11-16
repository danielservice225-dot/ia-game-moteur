#define MyAppName "IA GAME ML Studio"
#define MyAppVersion "0.1.0"
#define MyAppPublisher "SethOS Project"
#define MyAppExeName "IA-GAME-ML-Studio.exe"

[Setup]
AppId={{C21D6D3B-8A7A-4A5D-8D2E-2C7A8E6D1F30}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\IA GAME ML Studio
DefaultGroupName={#MyAppName}
OutputDir=..\installer-output
OutputBaseFilename=IA-GAME-ML-Studio-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64
UninstallDisplayIcon={app}\{#MyAppExeName}

[Files]
Source: "..\dist\IA-GAME-ML-Studio.exe"; DestDir: "{app}"; Flags: ignoreversion

[Tasks]
Name: "desktopicon"; Description: "Créer un raccourci sur le Bureau"; GroupDescription: "Raccourcis supplémentaires :"

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Lancer {#MyAppName}"; Flags: postinstall nowait skipifsilent
