; Inno Setup script for the Tide Windows installer.
;
; Build it with:
;   flutter build windows --release
;   "%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe" windows\packaging\tide.iss
;
; The result is one distributable file: .dist-scratch\windows\Tide-Setup-<ver>.exe
; (.dist-scratch is gitignored, like the macOS dmg scratch folder.)
;
; Deliberately a PER-USER install (PrivilegesRequired=lowest), for three
; reasons rather than one:
;   1. No UAC prompt, so the installer runs the way a tray utility should.
;   2. WebView2 writes its browser profile next to the exe
;      (ttabong.exe.WebView2\). Under Program Files that directory is not
;      writable and the dashboard would fail to start.
;   3. `UrlSchemeService` claims the dochi:// scheme under HKCU anyway, so
;      the install is already per-user in every way that matters.

#define AppName "Tide"
#define AppVersion "1.0.0"
#define AppPublisher "Dochi"
#define AppExe "ttabong.exe"
#define BuildDir "..\..\build\windows\x64\runner\Release"

[Setup]
; Never change AppId — it is what makes the next version replace this one
; instead of installing beside it.
AppId={{B1E5B0C6-7A4E-4C2F-9E3D-3F0A5D2B8C71}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
VersionInfoVersion={#AppVersion}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\..\.dist-scratch\windows
OutputBaseFilename={#AppName}-Setup-{#AppVersion}
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
; The app keeps running in the tray after its window is closed, so an
; upgrade will usually find it running. Let the restart manager close it.
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "korean"; MessagesFile: "compiler:Languages\Korean.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#BuildDir}\{#AppExe}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{group}\{cm:UninstallProgram,{#AppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Registry]
; Claim dochi:// up front so a sign-in deep link resolves even before the
; app has been run once. The app rewrites these on every launch
; (`UrlSchemeService`); they are here so uninstall can take them away again.
Root: HKCU; Subkey: "Software\Classes\dochi"; ValueType: string; ValueName: ""; ValueData: "URL:Dochi Protocol"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\dochi"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""
Root: HKCU; Subkey: "Software\Classes\dochi\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#AppExe}"" ""%1"""

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; WebView2's browser profile, created next to the exe at runtime.
Type: filesandordirs; Name: "{app}\{#AppExe}.WebView2"
