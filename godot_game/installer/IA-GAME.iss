#define AppName "IA GAME"
#define AppVersion "0.1.0"
#define AppPublisher "IA GAME Project"
#define AppExeName "IA-GAME.exe"

#ifndef SourceDir
  #define SourceDir "..\..\dist"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\release"
#endif

[Setup]
AppId={{8E80DA21-4C3D-4A77-A9B4-IA-GAME000001}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\IA GAME
DefaultGroupName={#AppName}
OutputDir={#OutputDir}
OutputBaseFilename=IA-GAME-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64
UninstallDisplayIcon={app}\{#AppExeName}
PrivilegesRequired=admin
CloseApplications=yes

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Créer un raccourci sur le Bureau"; GroupDescription: "Raccourcis supplémentaires :"; Flags: unchecked

[Files]
Source: "{#SourceDir}\{#AppExeName}"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\IA GAME"; Filename: "{app}\{#AppExeName}"
Name: "{autodesktop}\IA GAME"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "Lancer IA GAME"; Flags: postinstall nowait skipifsilent
