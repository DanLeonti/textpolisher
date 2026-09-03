import SwiftUI
import UIKit

@MainActor
final class ActionModel: ObservableObject {
    enum Phase: Equatable {
        case loading
        case ready
        case failed(String)
    }

    @Published var phase: Phase = .loading
    @Published var polished: String = ""
    @Published var tone: Tone {
        didSet {
            guard tone != oldValue else { return }
            ToneStore.defaultTone = tone
            repolish()
        }
    }

    let original: String
    private let onCancel: () -> Void
    private let onReplace: (String) -> Void
    private var task: Task<Void, Never>?

    init(
        original: String,
        onCancel: @escaping () -> Void,
        onReplace: @escaping (String) -> Void
    ) {
        self.original = original
        self.onCancel = onCancel
        self.onReplace = onReplace
        self.tone = ToneStore.defaultTone
    }

    func start() {
        repolish()
    }

    private func repolish() {
        task?.cancel()
        let selectedTone = tone
        phase = .loading
        task = Task { [original] in
            do {
                let result = try await PolishRunner.polish(original, tone: selectedTone)
                guard !Task.isCancelled else { return }
                polished = result
                phase = .ready
            } catch is CancellationError {
                // A newer re-polish superseded this one; ignore.
            } catch {
                guard !Task.isCancelled else { return }
                phase = .failed(error.localizedDescription)
            }
        }
    }

    func copyToClipboard() {
        UIPasteboard.general.string = polished
    }

    func replace() {
        onReplace(polished)
    }

    func cancel() {
        task?.cancel()
        onCancel()
    }
}

struct ActionView: View {
    @ObservedObject var model: ActionModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Tone") {
                    Picker("Tone", selection: $model.tone) {
                        ForEach(Tone.allCases) { tone in
                            Label(tone.title, systemImage: tone.systemImage).tag(tone)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Polished") {
                    switch model.phase {
                    case .loading:
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Polishing on-device...")
                                .foregroundStyle(.secondary)
                        }
                    case .ready:
                        Text(model.polished)
                            .textSelection(.enabled)
                    case .failed(let message):
                        Label(message, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }

                Section("Original") {
                    Text(model.original)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Polish")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { model.cancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Replace") { model.replace() }
                        .disabled(model.phase != .ready)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if model.phase == .ready {
                    Button {
                        model.copyToClipboard()
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .padding()
                }
            }
        }
    }
}
