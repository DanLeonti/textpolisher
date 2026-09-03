import Foundation
import Combine

@MainActor
final class OverlayViewModel: ObservableObject {
    @Published var originalText: String
    @Published var polishedText: String = ""
    @Published var isWorking: Bool = false
    @Published var tone: Tone
    @Published var errorMessage: String?
    @Published var engineName: String = ""

    private let engineProvider: EngineProvider
    private var task: Task<Void, Never>?

    var onAccept: ((String) -> Void)?
    var onCancel: (() -> Void)?

    init(originalText: String, tone: Tone, engineProvider: EngineProvider) {
        self.originalText = originalText
        self.tone = tone
        self.engineProvider = engineProvider
    }

    func start() {
        run()
    }

    func regenerate() {
        run()
    }

    func select(tone newTone: Tone) {
        guard newTone != tone || errorMessage != nil else { return }
        tone = newTone
        run()
    }

    var canAccept: Bool {
        !isWorking && errorMessage == nil && !polishedText.isEmpty
    }

    private func run() {
        task?.cancel()
        polishedText = ""
        errorMessage = nil
        isWorking = true

        let selectedTone = tone
        let original = originalText
        task = Task { [weak self] in
            guard let self else { return }
            let engine = await self.engineProvider.currentEngine()
            self.engineName = engine.displayName
            do {
                for try await partial in engine.stream(text: original, tone: selectedTone) {
                    if Task.isCancelled { return }
                    self.polishedText = OutputCleaner.clean(partial)
                }
            } catch is CancellationError {
                return
            } catch {
                self.errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            if !Task.isCancelled {
                self.isWorking = false
            }
        }
    }

    func accept() {
        guard canAccept else { return }
        task?.cancel()
        onAccept?(polishedText)
    }

    func cancel() {
        task?.cancel()
        onCancel?()
    }
}
