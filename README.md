# TextPolisher

A free, open-source macOS menu-bar app that polishes any selected text using a
**local, on-device model** (no API key, fully private). Select text in any app
(Slack desktop, browsers, editors), invoke **Polish Text** from the right-click
Services menu or a global hotkey, preview the rewrite in a floating overlay, and
replace the selection on Accept.

TextPolisher has no accounts, subscriptions, license keys, telemetry, or cloud
text processing. The source is available under the [MIT License](LICENSE).

## Features

- **Right-click anywhere**: adds a "Polish Text" item to the macOS Services menu
  (right-click on selected text) in any standard or Electron app.
- **Global hotkey**: Option+Cmd+P polishes the current selection from anywhere
  and shows a preview overlay.
- **Instant polish (no clicks)**: Option+Cmd+Shift+P polishes the selection with
  your default tone and replaces it in place - no overlay, no confirmation.
- **On-device, private**: uses Apple's Foundation Models framework (the model
  behind Apple Intelligence). Text never leaves your Mac. No API key, no cost.
- **Ollama fallback**: if Apple Intelligence is unavailable, or you prefer a
  larger/custom model, it falls back to a local Ollama server.
- **Tone presets**: Fix Grammar, Professional, Friendly, Concise.
- **Preview overlay**: see the original and polished text, regenerate, switch
  tone, then Replace or Cancel. Your selection is only changed when you accept.
- **Clipboard-safe**: the user's clipboard is backed up and restored around any
  copy/paste fallback.

## Requirements

- macOS 26 (Tahoe) or later.
- Apple Intelligence enabled (for the on-device engine), **or** a running
  [Ollama](https://ollama.com) instance for the fallback engine.
- Swift 6.2+ toolchain (Command Line Tools or Xcode).

## Install (for end users)

Download the latest notarized disk image from
[textpolisher.app](https://textpolisher.app/download), or build it yourself:

```bash
Scripts/make_dmg.sh
```

This produces `dist/TextPolisher.dmg`. The recipient:

1. Opens the `.dmg` and drags **TextPolisher** onto the **Applications** shortcut.
2. Opens it from Applications. On an ad-hoc build, macOS Gatekeeper warns the
   first time - go to System Settings > Privacy & Security and click
   **"Open Anyway"**. (Notarize the `.dmg` to remove this step - see below.)
3. Grants **Accessibility** access when prompted.

The DMG includes an "INSTALL - Read Me.txt" with these steps. To distribute,
attach `TextPolisher.dmg` to a GitHub Release (it is git-ignored, not committed).

> **Not on the Mac App Store.** The App Store requires the App Sandbox, which
> forbids reading text from other apps and synthesizing keystrokes into them -
> the core of how TextPolisher works. Like similar utilities, it is distributed
> as a notarized Developer ID `.dmg` (above), not through the App Store.

## App icon

The icon lives at `Packaging/AppIcon.icns` and is embedded by `build_app.sh`.
To regenerate it from a 1024x1024 PNG:

```bash
Scripts/make_icon.sh path/to/icon-1024.png
```

## Build from source

```bash
Scripts/build_app.sh
open dist/TextPolisher.app
```

This builds `dist/TextPolisher.app`, ad-hoc signs it, and refreshes the
macOS Services registry.

### First launch

1. **Grant Accessibility access** when prompted (System Settings > Privacy &
   Security > Accessibility). This is required to read and replace selected text.
2. **Enable the service**: System Settings > Keyboard > Keyboard Shortcuts >
   Services > Text > "Polish Text".
3. Select text anywhere, then either:
   - Right-click > Services > **Polish Text**, or
   - Press **Option+Cmd+P** to preview the rewrite in an overlay, or
   - Press **Option+Cmd+Shift+P** to polish and replace it instantly (no overlay).

The menu-bar icon (wand) lets you choose the engine, default tone, polish the
clipboard, check the on-device model status, and open Accessibility settings.

## Engines

Configured from the menu-bar icon > Engine:

- **Automatic** (default): use Apple on-device if available, else Ollama.
- **Apple On-Device**: Foundation Models. Private, offline, free.
- **Ollama (local)**: posts to `http://127.0.0.1:11434` using model `llama3.2`
  by default. Change via `defaults write com.textpolisher.app ollamaModel <name>`
  and `ollamaBaseURL`.

## Distribution (Developer ID + notarization)

Ad-hoc signing is fine for local use, but it makes recipients click through a
Gatekeeper warning on first open. With an Apple Developer ID you can produce a
signed, notarized `.dmg` that installs with **no warning** - in one command:

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
APPLE_ID="you@example.com" \
TEAM_ID="TEAMID" \
APP_PASSWORD="abcd-efgh-ijkl-mnop" \
Scripts/make_dmg.sh
```

`make_dmg.sh` signs the app with your Developer ID (hardened runtime), builds
`dist/TextPolisher.dmg`, then notarizes and staples it automatically.

- Find your signing identity name with `security find-identity -v -p codesigning`
  (use the full `Developer ID Application: ...` string).
- `APP_PASSWORD` is an **app-specific password** from
  [appleid.apple.com](https://appleid.apple.com) (Sign-In and Security >
  App-Specific Passwords) - not your Apple ID password.

To avoid re-entering credentials, store them once and use a profile:

```bash
xcrun notarytool store-credentials text_polisher \
  --apple-id you@example.com --team-id TEAMID --password <app-specific-password>

SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE="text_polisher" Scripts/make_dmg.sh
```

The app must run with App Sandbox **off** (it uses the Accessibility API and
synthesized keystrokes), so it is distributed outside the Mac App Store.

## Troubleshooting

**"Replace" does nothing / text is not inserted.** The app injects the polished
text with the Accessibility API and a synthesized paste, both of which require
Accessibility access. After every rebuild of an *ad-hoc signed* build the macOS
Accessibility grant is invalidated (the binary hash changes), so:

1. Open System Settings > Privacy & Security > Accessibility.
2. If "TextPolisher" is listed, remove it with "-" and add the new build, or
   toggle it off and on.
3. Re-run and try again. The app will also prompt you automatically when it
   detects it is not trusted.

To avoid re-granting on every build, sign with a stable identity (a Developer ID,
or a self-signed "text_polisher Local" code-signing certificate created via
Keychain Access > Certificate Assistant). `Scripts/build_app.sh` uses it
automatically if present.

## How it works

```
Select text  ->  Trigger (Services menu OR Option+Cmd+P)
             ->  TextCapture  (Accessibility -> browser AppleScript -> Cmd+C fallback)
             ->  PolishEngine (Apple Foundation Models, or Ollama fallback)
             ->  Overlay preview (Accept / Regenerate / change tone)
             ->  TextReplace  (Accessibility set value -> Cmd+V fallback)
```

The overlay is a non-activating floating panel, so the app you were using stays
frontmost and its selection/focus is preserved for the replace step.

## Contributing

Issues and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for
the development workflow and contribution guidelines.

For security issues, follow the private reporting instructions in
[SECURITY.md](SECURITY.md).

## Project layout

| Path | Purpose |
| --- | --- |
| `Sources/text_polisher/App.swift` | Entry point (`LSUIElement` agent). |
| `AppDelegate.swift` | Wires up services, hotkey, menu bar. |
| `PolishCoordinator.swift` | Orchestrates capture -> polish -> replace. |
| `ServicesProvider.swift` | `NSServices` "Polish Text" handler. |
| `HotKeyManager.swift` | Carbon global hotkey (Option+Cmd+P). |
| `TextCapture.swift` / `TextReplace.swift` | Layered selection read/write. |
| `Pasteboard.swift` / `KeyboardSimulator.swift` | Clipboard-safe helpers. |
| `Engine/` | `PolishEngine` protocol, Foundation Models + Ollama engines, prompts. |
| `Overlay/` | SwiftUI overlay view, view model, panel controller. |
| `MenuBarController.swift` | Status-bar menu. |
| `Settings.swift` | Persisted engine/tone preferences. |
| `Packaging/Info.plist` | Bundle config: `LSUIElement`, `NSServices`. |
| `Scripts/build_app.sh` | Build, sign, register services. |
