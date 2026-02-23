; My Leadership Quest - Windows Installer Script
; Inno Setup 6.x required (https://jrsoftware.org/isinfo.php)

#define MyAppName "My Leadership Quest"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "My Leadership Quest"
#define MyAppURL "https://yourwebsite.com"
#define MyAppExeName "my_leadership_quest.exe"
#define MyAppId "{{8F7A9B2C-3D4E-5F6A-7B8C-9D0E1F2A3B4C}"

[Setup]
; Basic Information
AppId={#MyAppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}

; Installation Directories
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes

; Output Configuration
OutputDir=installer_output
OutputBaseFilename=MyLeadershipQuest_Setup_v{#MyAppVersion}
SetupIconFile=assets\images\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}

; Compression
Compression=lzma2/max
SolidCompression=yes

; Windows Version Requirements
MinVersion=10.0.17763
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

; Privileges
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

; UI Configuration
WizardStyle=modern
DisableWelcomePage=no
; LicenseFile=assets\legal\terms_of_service.txt

; Uninstall
UninstallDisplayName={#MyAppName}
UninstallFilesDir={app}\uninstall

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked; OnlyBelowVersion: 6.1; Check: not IsAdminInstallMode

[Files]
; Main executable
Source: "build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion

; Flutter engine and plugins
Source: "build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\x64\runner\Release\*.lib"; DestDir: "{app}"; Flags: ignoreversion

; Data folder (assets, ICU data)
Source: "build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

; Visual C++ Redistributable (download from Microsoft)
; Download from: https://aka.ms/vs/17/release/vc_redist.x64.exe
; Place in the project root directory
Source: "vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Icons]
; Start Menu
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"

; Desktop Icon (optional)
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

; Quick Launch (optional, for older Windows)
Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: quicklaunchicon

[Run]
; Install Visual C++ Redistributable silently (with better error handling)
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; StatusMsg: "Installing Visual C++ Runtime..."; Flags: waituntilterminated skipifdoesntexist

; Option to launch app after installation
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
// Check if WebView2 Runtime is installed
function IsWebView2Installed: Boolean;
var
  RegKey: String;
begin
  RegKey := 'SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}';
  Result := RegKeyExists(HKEY_LOCAL_MACHINE, RegKey);
  if not Result then
  begin
    RegKey := 'SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}';
    Result := RegKeyExists(HKEY_LOCAL_MACHINE, RegKey);
  end;
end;

// Prompt to install WebView2 if not found
function InitializeSetup: Boolean;
var
  ResultCode: Integer;
begin
  Result := True;
  
  if not IsWebView2Installed then
  begin
    if MsgBox('This application requires Microsoft Edge WebView2 Runtime.' + #13#10 + #13#10 +
              'Would you like to download and install it now?' + #13#10 + #13#10 +
              'Note: Internet connection required.', 
              mbConfirmation, MB_YESNO) = IDYES then
    begin
      ShellExec('open', 
                'https://go.microsoft.com/fwlink/p/?LinkId=2124703',
                '', '', SW_SHOW, ewNoWait, ResultCode);
      MsgBox('Please install WebView2 Runtime and run this installer again.', 
             mbInformation, MB_OK);
      Result := False;
    end
    else
    begin
      if MsgBox('The application may not work correctly without WebView2 Runtime.' + #13#10 + #13#10 +
                'Do you want to continue anyway?',
                mbConfirmation, MB_YESNO) = IDNO then
      begin
        Result := False;
      end;
    end;
  end;
end;

// Display completion message
procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    // Any post-installation tasks can go here
  end;
end;
