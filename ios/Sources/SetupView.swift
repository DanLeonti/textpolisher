import SwiftUI

struct SetupView: View {
    /// Shared "Polish" shortcut (Get Clipboard -> Polish Text -> Copy to Clipboard).
    /// Update this if you re-share the shortcut from the Shortcuts app.
    private let shortcutURL = URL(string: "https://www.icloud.com/shortcuts/a216087403c141cd9549282a9567746d")!

    @State private var tone: Tone = ToneStore.defaultTone
    @State private var modelAvailable = false
    @State private var modelStatus = "Checking..."

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        statusIcon(ok: modelAvailable)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Apple Intelligence")
                                .font(.headline)
                            Text(modelStatus)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if !modelAvailable {
                        Button("Open Settings to enable") { openSettings() }
                    }
                } header: {
                    Text("Step 1 - On-device model")
                } footer: {
                    Text("Polishing runs entirely on your device. Your text never leaves the phone.")
                }

                Section {
                    Label("Tap below to add the ready-made shortcut, then tap Add Shortcut in the Shortcuts app.", systemImage: "square.and.arrow.down")
                        .font(.subheadline)
                    Button {
                        UIApplication.shared.open(shortcutURL)
                    } label: {
                        Label("Get the Polish Shortcut", systemImage: "link")
                            .frame(maxWidth: .infinity)
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                } header: {
                    Text("Step 2 - Install the shortcut")
                }

                Section {
                    Picker("Tone", selection: $tone) {
                        ForEach(Tone.allCases) { tone in
                            Label(tone.title, systemImage: tone.systemImage).tag(tone)
                        }
                    }
                } header: {
                    Text("Step 3 - Default tone")
                } footer: {
                    Text("Used every time you polish.")
                }

                Section {
                    bindRow("Action Button", "Settings > Action Button > swipe to Shortcut > pick \"Polish\".")
                    bindRow("Back Tap", "Settings > Accessibility > Touch > Back Tap > Double Tap > pick \"Polish\".")
                } header: {
                    Text("Step 4 - Add to a button")
                } footer: {
                    Text("Then: select text, Copy, press the button, Paste the polished result.")
                }
            }
            .navigationTitle("Polish")
            .scrollContentBackground(.visible)
            .onChange(of: tone) { _, newValue in
                ToneStore.defaultTone = newValue
            }
            .task {
                let engine = FoundationModelsEngine()
                modelAvailable = await engine.isAvailable()
                modelStatus = FoundationModelsEngine.availabilityDescription()
            }
        }
    }

    private func statusIcon(ok: Bool) -> some View {
        Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            .font(.title2)
            .foregroundStyle(ok ? .green : .orange)
    }

    private func bindRow(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.subheadline.bold())
            Text(detail).font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

#Preview {
    SetupView()
}
