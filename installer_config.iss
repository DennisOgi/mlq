; Inno Setup Script for My Leadership Quest
; Download Inno Setup from: https://jrsoftware.org/isdl.php

#define MyAppName "My Leadership Quest"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "MLQ"
#define MyAppURL "https://mlq.app"
#define MyAppExeName "my_leadership_quest.exe"

[Setup]
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
LicenseFile=
OutputDir=installer_output
OutputBaseFilename=MyLeadershipQuest_Setup_v{#MyAppVersion}
SetupIconFile=assets\images\app_icon.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
; Minimum Windows version
MinVersion=10.0

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Main executable
Source: "build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion

; All DLL files from the build directory
Source: "build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion

; Data folder with all assets
Source: "build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

; Visual C++ Redistributable - INCLUDED for maximum compatibility
Source: "redist\vcredist_x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

; Additional system DLLs that might be needed (bundled with app)
; These will be copied from the Release folder automatically with *.dll pattern above

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; Install Visual C++ Redistributable automatically
Filename: "{tmp}\vcredist_x64.exe"; Parameters: "/quiet /norestart"; StatusMsg: "Installing Microsoft Visual C++ Redistributables..."; Flags: waituntilterminated; Check: VCRedistNeedsInstall

; Launch the application
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
// Check if Visual C++ Redistributables are installed
function VCRedistNeedsInstall: Boolean;
var
  Version: String;
begin
  // Check for VC++ 2015-2022 Redistributable (x64)
  if RegQueryStringValue(HKLM, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64', 'Version', Version) then
    Result := False
  else
    Result := True;
end;

// Custom message for missing dependencies
function InitializeSetup(): Boolean;
begin
  Result := True;
  
  // Check if VC++ Redistributables are needed
  if VCRedistNeedsInstall then
  begin
    // Inform user that VC++ will be installed automatically
    MsgBox('This application requires Microsoft Visual C++ Redistributables.' + #13#10 + 
           'They will be installed automatically during setup.' + #13#10 + #13#10 +
           'This is a one-time installation and ensures the app runs smoothly.', 
           mbInformation, MB_OK);
  end;
end;
