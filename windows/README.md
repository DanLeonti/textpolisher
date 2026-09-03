# TextPolisher for Windows

A system-wide Windows tray app that polishes any selected text using a
**local AI model** running on your own PC (via [Ollama](https://ollama.com)) -
no API key, no cloud, fully private. Select text in any app (Slack, browsers,
editors), press a hotkey, preview the rewrite in a floating overlay, and replace
the selection on Accept.

This is the Windows port of the macOS TextPolisher. It reuses the same prompts,
tone presets, and output-cleaning logic so results match the Mac version. On
Windows the engine is Ollama (there is no Apple Foundation Models equivalent).

## Features

- **Global hotkey** - `Ctrl+Alt+P` polishes the current selection and shows a
  preview overlay.
- **Instant polish (no clicks)** - `Ctrl+Alt+Shift+P` polishes the selection
  with your default tone and replaces it in place, no overlay.
- **Polish clipboard** - polish whatever is on your clipboard and copy the
  result back.
- **On-device, private** - text is processed by a local Ollama model. Nothing
  leaves your PC.
- **Tone presets** - Fix Grammar (default), Professional, Friendly, Concise.
- **Preview overlay** - see original vs. polished text, switch tone, regenerate,
  then Replace (Enter) or Cancel (Esc).
- **Clipboard-safe** - your clipboard is snapshotted and restored around any
  copy/paste fallback.
- **Runs in the tray** - lives in the system tray, optional start-on-login.

## Requirements

- Windows 10 or 11 (x64).
- [Ollama](https://ollama.com) - installed automatically by the installer.
- The default model `qwen2.5:3b` (~2 GB) - downloaded on first launch.

## Install (for end users)

1. Download and run `TextPolisher-Setup.exe`.
2. The installer installs the app (per-user, no admin needed) and, if Ollama is
   not already present, downloads and installs it silently.
3. Launch TextPolisher. On first run it downloads the default AI model
   (`qwen2.5:3b`, ~2 GB) with a progress window. This happens once.
4. TextPolisher now lives in your system tray. Select text anywhere and press
   **Ctrl+Alt+P**.

## Usage

1. Select text in any app.
2. Either:
   - Press **Ctrl+Alt+P** to preview the rewrite in an overlay, or
   - Press **Ctrl+Alt+Shift+P** to polish and replace it instantly.
3. In the overlay: switch tone, **Regenerate**, then **Replace** (Enter) or
   **Cancel** (Esc).

Right-click the tray icon to polish the clipboard, change the default tone or
model, edit shortcuts, check the model status, toggle start-on-login, or quit.

## Build from source

Prerequisites:

- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)
- [Inno Setup 6](https://jrsoftware.org/isdl.php) (only needed to build the
  installer)

```powershell
# From the windows\ folder
dotnet build TextPolisher.sln -c Release      # compile
dotnet run --project src\TextPolisher          # run locally

# Produce the self-contained app + one-click installer
.\build.ps1                                    # -> windows\dist\TextPolisher-Setup.exe
```

`build.ps1` publishes a **self-contained** build (no .NET runtime required on the
target PC) and compiles the installer.

## How it works

```
Select text  ->  Hotkey (Ctrl+Alt+P)
             ->  TextCapture  (UI Automation -> Ctrl+C clipboard fallback)
             ->  OllamaEngine (POST /api/generate, streaming)
             ->  OutputCleaner (strip preambles / quotes)
             ->  Overlay preview (Accept / Regenerate / change tone)
             ->  TextReplace  (UI Automation SetValue -> Ctrl+V fallback)
```

The app captures the foreground window when you trigger it, then restores focus
to it before injecting the polished text.

## Project layout

| Path | Purpose |
| --- | --- |
| `src/TextPolisher/App.xaml.cs` | Composition root (tray-only background app). |
| `PolishCoordinator.cs` | Orchestrates capture -> polish -> replace. |
| `Engine/` | `IPolishEngine`, `OllamaEngine`, prompts, tones, output cleaner. |
| `Capture/` | UI Automation capture/replace, clipboard + input simulation. |
| `Hotkeys/` | Global hotkeys (`RegisterHotKey`) and shortcut model. |
| `Overlay/` | Preview overlay window + view model. |
| `Tray/` | System-tray icon and menu. |
| `Focus/` | Foreground-window tracking. |
| `Ollama/` | First-run server + model bootstrap. |
| `Setup/` | Model-download progress window. |
| `Preferences/` | Shortcut recorder window. |
| `Settings/` | JSON settings in `%AppData%\TextPolisher`. |
| `installer/TextPolisher.iss` | Inno Setup installer (auto-installs Ollama). |
| `build.ps1` | Publish + compile installer. |

## Configuration

Settings are stored at `%AppData%\TextPolisher\settings.json`:

- `OllamaBaseUrl` (default `http://127.0.0.1:11434`)
- `OllamaModel` (default `qwen2.5:3b`)
- `DefaultTone` (default `fixGrammar`)
- Hotkeys and start-on-login.

Change the model or tone from the tray menu, or edit the JSON directly.

## Troubleshooting

**"Replace" does nothing / text is not inserted.** Some apps block synthesized
input when the app is running elevated. Run TextPolisher **without** administrator
rights. For elevated target apps, replacement may be blocked by Windows (UIPI).

**Nothing to polish.** Make sure text is actually selected before pressing the
hotkey. In some web/Electron fields, TextPolisher falls back to a `Ctrl+C` copy
to read the selection.

**Model not ready / polish fails.** Open the tray menu -> **Model Status...** to
confirm Ollama is running and the model is installed. You can (re)download a model
manually with `ollama pull qwen2.5:3b`.

**Hotkey doesn't work.** Another app may have registered the same global hotkey.
Change it via tray -> **Shortcuts...**.

## Not ported from macOS

- Apple Foundation Models engine (no Windows equivalent; Ollama is used instead).
- macOS Services-menu integration (Windows has no equivalent; the hotkeys, tray,
  and clipboard actions cover the same use cases).
