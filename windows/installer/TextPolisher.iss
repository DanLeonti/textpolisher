; Inno Setup script for TextPolisher (Windows).
; Installs the app per-user (no UAC), and auto-downloads + silently installs
; Ollama if it is not already present. The default AI model is downloaded on
; first launch of the app (with a progress window).
;
; Build with:  iscc /DAppVersion=1.0.0 TextPolisher.iss
; Requires Inno Setup 6.1 or later (for CreateDownloadPage).

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

#define AppName "TextPolisher"
#define AppPublisher "TextPolisher"
#define AppExeName "TextPolisher.exe"
#define OllamaUrl "https://ollama.com/download/OllamaSetup.exe"

[Setup]
AppId={{7F2C4E1A-9B3D-4C6E-8A2F-1D5B7E9C3A40}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={localappdata}\Programs\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
DisableDirPage=yes
PrivilegesRequired=lowest
OutputDir=..\dist
OutputBaseFilename=TextPolisher-Setup
SetupIconFile=..\src\TextPolisher\Assets\app.ico
UninstallDisplayIcon={app}\{#AppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
ArchitecturesAllowed=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"
Name: "startupicon"; Description: "Start TextPolisher automatically when I sign in"; GroupDescription: "Startup:"

[Files]
; Published self-contained app output (see build.ps1 -> ..\publish).
Source: "..\publish\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{userdesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon
Name: "{userstartup}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: startupicon

[Run]
; Silently install Ollama if we downloaded it (only when not already present).
Filename: "{tmp}\OllamaSetup.exe"; Parameters: "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART"; \
  StatusMsg: "Installing Ollama (local AI runtime)..."; Check: NeedsOllama; Flags: waituntilterminated

; Launch the app. On first launch it downloads the default AI model.
Filename: "{app}\{#AppExeName}"; Description: "Launch {#AppName}"; \
  Flags: nowait postinstall skipifsilent

[Code]
var
  DownloadPage: TDownloadWizardPage;

function OllamaInstalled(): Boolean;
begin
  Result := FileExists(ExpandConstant('{localappdata}\Programs\Ollama\ollama.exe')) or
            FileExists(ExpandConstant('{commonpf}\Ollama\ollama.exe')) or
            FileExists(ExpandConstant('{commonpf32}\Ollama\ollama.exe'));
end;

function NeedsOllama(): Boolean;
begin
  Result := not OllamaInstalled();
end;

function OnDownloadProgress(const Url, FileName: String; const Progress, ProgressMax: Int64): Boolean;
begin
  if ProgressMax <> 0 then
    Log(Format('Downloading %s: %d of %d', [FileName, Progress, ProgressMax]));
  Result := True;
end;

procedure InitializeWizard;
begin
  DownloadPage := CreateDownloadPage(
    'Preparing Ollama', 'Downloading the local AI runtime required by TextPolisher.',
    @OnDownloadProgress);
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  if (CurPageID = wpReady) and NeedsOllama() then
  begin
    DownloadPage.Clear;
    DownloadPage.Add('{#OllamaUrl}', 'OllamaSetup.exe', '');
    DownloadPage.Show;
    try
      try
        DownloadPage.Download;
      except
        if not DownloadPage.AbortedByUser then
          SuppressibleMsgBox(
            'Could not download Ollama automatically. You can install it later from ' +
            'https://ollama.com/download - TextPolisher will use it once it is installed.',
            mbInformation, MB_OK, IDOK);
      end;
    finally
      DownloadPage.Hide;
    end;
  end;
end;
