import AppKit

/// Orchestrates the full flow: capture selection -> show overlay -> polish ->
/// replace on accept. Both the global hotkey and the Services menu funnel here.
@MainActor
final class PolishCoordinator {
    private let settings = Settings.shared
    private let capture = TextCapture()
    private lazy var replacer: TextReplace = {
        let replacer = TextReplace()
        replacer.onSecureInputBlocked = { [weak self] in self?.notifySecureInputBlocked() }
        return replacer
    }()
    private lazy var engineProvider = EngineProvider(settings: settings)
    private let overlay = OverlayController()

    /// The app that was frontmost when polishing started. We reactivate it
    /// before injecting the replacement so the keystrokes/AX writes land in the
    /// right text field.
    private var sourceApp: NSRunningApplication?

    /// In-flight instant polish (no overlay). Cancelled if retriggered.
    private var instantTask: Task<Void, Never>?

    /// Fired around an instant polish so the UI (menu-bar icon) can show that
    /// work is in progress. `true` when polishing starts, `false` when it ends.
    var onBusyChanged: ((Bool) -> Void)?

    func polishFromHotKey() {
        Log.polish.info("Trigger: polish+preview")
        guard Permissions.isAccessibilityTrusted else {
            Log.polish.error("Accessibility not trusted; prompting")
            promptForAccessibility()
            return
        }
        captureSourceApp()
        guard let selection = capture.currentSelection()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !selection.isEmpty else {
            Log.polish.info("No selection captured")
            notify("Select some text first, then trigger Polish Text.")
            return
        }
        Log.polish.info("Captured selection (\(selection.count, privacy: .public) chars) from \(self.sourceApp?.bundleIdentifier ?? "unknown", privacy: .public)")
        Task { [weak self] in
            guard let self, await self.ensureEngineReady() else { return }
            self.present(text: selection)
        }
    }

    /// One-shot flow: capture the selection, polish it with the default tone,
    /// and replace it in place - no overlay, no confirmation, no extra clicks.
    func polishInstant() {
        Log.polish.info("Trigger: instant polish+replace")
        guard Permissions.isAccessibilityTrusted else {
            Log.polish.error("Accessibility not trusted; prompting")
            promptForAccessibility()
            return
        }
        captureSourceApp()
        guard let selection = capture.currentSelection()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !selection.isEmpty else {
            Log.polish.info("No selection captured")
            notify("Select some text first, then trigger Polish Text.")
            return
        }
        Log.polish.info("Captured selection (\(selection.count, privacy: .public) chars) from \(self.sourceApp?.bundleIdentifier ?? "unknown", privacy: .public)")
        Task { [weak self] in
            guard let self, await self.ensureEngineReady() else { return }
            self.polishAndReplace(text: selection)
        }
    }

    private func polishAndReplace(text: String) {
        let tone = settings.defaultTone
        instantTask?.cancel()
        onBusyChanged?(true)
        instantTask = Task { [weak self] in
            guard let self else { return }
            defer { self.onBusyChanged?(false) }
            let engine = await self.engineProvider.currentEngine()
            Log.engine.info("Instant polish via \(engine.displayName, privacy: .public), tone=\(tone.rawValue, privacy: .public)")
            do {
                var result = ""
                for try await partial in engine.stream(text: text, tone: tone) {
                    if Task.isCancelled { return }
                    result = OutputCleaner.clean(partial)
                }
                if Task.isCancelled { return }
                let final = result.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !final.isEmpty else {
                    Log.engine.error("Engine returned empty result")
                    self.notify("Couldn't polish the text (the engine returned nothing). Try again, or switch engine/tone from the menu bar.")
                    return
                }
                Log.engine.info("Polished OK (\(final.count, privacy: .public) chars); replacing")
                self.performReplace(with: final)
            } catch is CancellationError {
                return
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                Log.engine.error("Polish failed: \(message, privacy: .public)")
                self.notify("Couldn't polish the text: \(message)")
            }
        }
    }

    func polish(text: String) {
        captureSourceApp()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task { [weak self] in
            guard let self, await self.ensureEngineReady() else { return }
            self.present(text: trimmed)
        }
    }

    private func captureSourceApp() {
        // Prefer the last app that was active before us. When triggered from the
        // Services menu, macOS has already made us frontmost, so reading
        // frontmostApplication here would return us instead of the real target.
        sourceApp = AppFocusTracker.shared.lastApp
        let front = NSWorkspace.shared.frontmostApplication
        if let front, front.bundleIdentifier != Bundle.main.bundleIdentifier {
            sourceApp = front
        }
    }

    private func present(text: String) {
        let viewModel = OverlayViewModel(
            originalText: text,
            tone: settings.defaultTone,
            engineProvider: engineProvider
        )
        viewModel.onAccept = { [weak self] polished in
            self?.performReplace(with: polished)
        }
        viewModel.onCancel = { [weak self] in
            self?.overlay.close()
        }
        overlay.show(viewModel: viewModel)
        viewModel.start()
    }

    private func performReplace(with text: String) {
        overlay.close()

        guard Permissions.isAccessibilityTrusted else {
            promptForAccessibility()
            return
        }

        // On macOS 14+ the active app must yield activation before another app
        // can be brought forward (cooperative activation).
        if let target = sourceApp {
            NSApp.yieldActivation(to: target)
        }

        // Return focus to the originating app, then inject only once it is
        // actually frontmost again. Electron apps (Slack) can take longer than a
        // fixed delay to come forward, so we poll instead of guessing.
        reactivateThenReplace(with: text, attemptsRemaining: 40)
    }

    private func reactivateThenReplace(with text: String, attemptsRemaining: Int) {
        let replacer = self.replacer

        guard let target = sourceApp, !target.isTerminated else {
            // We don't know where to put the text; copy it so the user can paste
            // it manually instead of beeping into our own window.
            Log.replace.error("No source app to paste into; left text on clipboard")
            PasteboardHelper.setString(text)
            notify("Couldn't find the app to paste into. The polished text is on your clipboard - press Cmd+V to paste it.")
            return
        }

        let isFrontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier
        if isFrontmost {
            Log.replace.info("Source app \(target.bundleIdentifier ?? "unknown", privacy: .public) is frontmost; replacing")
            // Brief settle so the app's focused field regains key status (the
            // overlay may have been the key window) before we inject.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                replacer.replace(with: text)
            }
            return
        }

        if attemptsRemaining <= 0 {
            Log.replace.error("Couldn't refocus \(target.bundleIdentifier ?? "unknown", privacy: .public) after retries; left text on clipboard")
            PasteboardHelper.setString(text)
            notify("Couldn't return focus to \(target.localizedName ?? "the app"). The polished text is on your clipboard - press Cmd+V to paste it.")
            return
        }

        target.activate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { [weak self] in
            self?.reactivateThenReplace(with: text, attemptsRemaining: attemptsRemaining - 1)
        }
    }

    /// Verifies the engine that will actually run is ready before we capture the
    /// user's attention with an overlay or replace their text. When Apple
    /// Intelligence is the (effective) engine but isn't enabled/ready, shows a
    /// clear, actionable message and returns false so the caller bails out.
    private func ensureEngineReady() async -> Bool {
        switch settings.engineChoice {
        case .ollama:
            // Ollama connection problems surface as a clear error while streaming.
            return true
        case .appleOnDevice:
            let status = FoundationModelsEngine.status()
            guard status.isAvailable else {
                presentAppleIntelligenceGuidance(status)
                return false
            }
            return true
        case .auto:
            let status = FoundationModelsEngine.status()
            if status.isAvailable { return true }
            // Apple is unavailable; quietly use Ollama if it's running.
            let ollama = OllamaEngine(baseURL: settings.ollamaBaseURL, model: settings.ollamaModel)
            if await ollama.isAvailable() { return true }
            presentAppleIntelligenceGuidance(status)
            return false
        }
    }

    private func presentAppleIntelligenceGuidance(_ status: FoundationModelsEngine.AppleIntelligenceStatus) {
        let guidance = FoundationModelsEngine.guidance(for: status)
        let alert = NSAlert()
        alert.messageText = guidance.title
        alert.informativeText = guidance.message
        alert.alertStyle = .warning
        if guidance.canOpenAppleIntelligence {
            alert.addButton(withTitle: "Open Settings")
            alert.addButton(withTitle: "Not Now")
            if alert.runModal() == .alertFirstButtonReturn {
                Permissions.openAppleIntelligenceSettings()
            }
        } else {
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    private func promptForAccessibility() {
        let alert = NSAlert()
        alert.messageText = "Accessibility access needed"
        alert.informativeText = """
        TextPolisher needs Accessibility access to read and replace your selected text.

        Enable it in System Settings > Privacy & Security > Accessibility.

        If "TextPolisher" is already listed but still not working (common after rebuilding), remove it with the "-" button and add it again, or toggle it off and on.
        """
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            Permissions.openAccessibilitySettings()
        }
    }

    private func notifySecureInputBlocked() {
        let alert = NSAlert()
        alert.messageText = "Couldn't paste the polished text automatically"
        alert.informativeText = """
        macOS "Secure Input" is currently active, which blocks apps from typing or pasting on your behalf. It's normally turned on by password fields, but some apps leave it stuck on by mistake.

        Your polished text is on the clipboard — just press Cmd+V to paste it.

        To stop this from happening again, quit whatever app left Secure Input on. The usual culprits are password managers (1Password is the most common) and Chromium/Electron apps like Slack and browsers. Quitting 1Password, or fully quitting and reopening Slack (Cmd+Q, then relaunch), clears the stuck state.
        """
        alert.alertStyle = .warning
        alert.runModal()
    }

    private func notify(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "TextPolisher"
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.runModal()
    }
}
