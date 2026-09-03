# TextPolisher for iPhone

An iOS companion to the macOS TextPolisher. Its core is a single App Intent that
**polishes whatever text is on your clipboard, on-device**, and writes the result
back - designed to be triggered with one press of the **Action Button**.

Copy text in any app, press the Action Button, paste the polished result. The
rewrite runs entirely on-device with Apple's Foundation Models (Apple
Intelligence) - nothing leaves your phone, no API key, no cost.

## Requirements

- **iPhone 15 Pro or newer** on **iOS 26** (the Action Button and Apple
  Intelligence are unavailable on older devices and in the Simulator).
- Apple Intelligence enabled (Settings > Apple Intelligence & Siri).
- Xcode 26 and a signing identity (a free personal Apple ID works for on-device
  testing; App Store / TestFlight needs a paid Apple Developer account).

## Build

The Xcode project is generated from [`project.yml`](project.yml) with
[XcodeGen](https://github.com/yonyz/XcodeGen) (the `.xcodeproj` is git-ignored
and regenerated):

```bash
brew install xcodegen
cd ios
xcodegen generate
open TextPolisher-iOS.xcodeproj
```

In Xcode: select the **TextPolisher** target > Signing & Capabilities > set your
**Team**, then build and run on your iPhone.

## First-time setup (on the phone)

1. Launch the app once. Pick your **default tone** (Fix Grammar, Professional,
   Friendly, Concise) and confirm the on-device model shows **Available**.
2. Build a shortcut that handles the clipboard (a background App Intent cannot
   read `UIPasteboard.general` itself, so the Shortcut must do it). In the
   **Shortcuts** app, tap **+** and add these three actions in order:
   1. **Get Clipboard**
   2. **Polish Text** (from this app) - set its input to the **Clipboard**
      variable from step 1.
   3. **Copy to Clipboard** - set its input to the **Polished Text** result.
   Name it e.g. "Polish" and save.
3. Bind that shortcut to a trigger:
   - **Action Button** (iPhone 15 Pro / Pro Max / any iPhone 16): **Settings >
     Action Button** (its own top-level page) > swipe to **Shortcut** > choose
     your "Polish" shortcut.
   - **Back Tap** (any iPhone): **Settings > Accessibility > Touch > Back Tap >
     Double Tap** > under **Shortcuts**, choose your "Polish" shortcut.

## Use

There are three ways to polish, each suited to a different situation:

### A. Action Button / Back Tap (clipboard)

```
Select text + Copy  ->  press the button  ->  paste
```

The shortcut runs in the background (no app switch): it reads the clipboard,
polishes it on-device with your default tone, and writes the result back so you
can paste it. Copy and Paste stay manual - iOS does not expose the live text
selection to a shortcut, and a shortcut cannot paste into another app.

### B. Share Sheet (selected text, no Copy needed)

```
Select text  ->  Share  ->  "Polish Selected Text"  ->  paste
```

`PolishSelectionIntent` is registered as an App Shortcut with a single text
parameter, so iOS offers it in the Share Sheet for any selected text. It
polishes with your **default tone**, copies the result to the clipboard, and
shows it for review. (App Intents can't replace the selection in place - for
that, use the Action Extension below.)

### C. Action Extension (replace selection in place)

```
Select text  ->  Share  ->  "Polish"  ->  pick tone  ->  Replace
```

The `PolishAction` extension opens a small sheet with the polished text and a
tone picker (change the tone to re-polish on the spot). Tapping **Replace**
returns the text to the host app, which swaps your selection in place **if the
host supports receiving edited text** (many editable text views do; some custom
editors and read-only views don't, in which case use **Copy** and paste). The
extension runs in its own process, so it has its own tone picker rather than
reading the app's default.

## Notes

- One Action Button press = one tone (your saved default). To use multiple tones,
  open the Shortcuts app, duplicate shortcuts around the "Polish Text" action, or
  trigger via Siri ("Polish my text with TextPolisher").
- Reading the clipboard may show iOS's "pasted from" banner the first time.
- The polishing engine, prompts, tones, and output cleanup are shared verbatim
  with the macOS app (`../Sources/text_polisher/Engine/`). Ollama is not used on
  iOS.

## Project layout

| Path | Purpose |
| --- | --- |
| `project.yml` | XcodeGen spec (target, iOS 26, shared engine sources). |
| `Info.plist` | Minimal app bundle config. |
| `Sources/PolishApp.swift` | SwiftUI `@main` entry point. |
| `Sources/SetupView.swift` | Tone picker, model status, Action Button guide. |
| `Sources/PolishIntent.swift` | The silent clipboard polish App Intent. |
| `Sources/PolishSelectionIntent.swift` | Share Sheet intent (copies result + shows snippet). |
| `Sources/PolishShortcuts.swift` | Exposes both intents to Shortcuts / Action Button / Share Sheet. |
| `Sources/PolishRunner.swift` | Shared polishing pipeline used by every entry point. |
| `Sources/ToneStore.swift` | Persists the default tone. |
| `Sources/Assets.xcassets` | App icon slot. |
| `PolishAction/` | Action Extension target (replace selection in supporting apps). |
