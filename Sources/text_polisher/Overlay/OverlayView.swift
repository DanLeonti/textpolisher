import SwiftUI

struct OverlayView: View {
    @ObservedObject var viewModel: OverlayViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            tonePicker
            originalSection
            Divider()
            polishedSection
            footer
        }
        .padding(16)
        .frame(width: 480)
        .background(.regularMaterial)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "wand.and.stars")
                .foregroundStyle(.tint)
            Text("Polish Text")
                .font(.headline)
            Spacer()
            if !viewModel.engineName.isEmpty {
                Text(viewModel.engineName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var tonePicker: some View {
        HStack(spacing: 8) {
            ForEach(Tone.allCases) { tone in
                let isSelected = tone == viewModel.tone
                Button {
                    viewModel.select(tone: tone)
                } label: {
                    Label(tone.title, systemImage: tone.systemImage)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
            }
            Spacer()
        }
    }

    private var originalSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Original")
                .font(.caption2)
                .foregroundStyle(.secondary)
            ScrollView {
                Text(viewModel.originalText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 70)
        }
    }

    private var polishedSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("Polished")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if viewModel.isWorking {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            ScrollView {
                Group {
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.callout)
                            .foregroundStyle(.red)
                    } else if viewModel.polishedText.isEmpty && viewModel.isWorking {
                        Text("Polishing…")
                            .font(.callout)
                            .foregroundStyle(.tertiary)
                    } else {
                        Text(viewModel.polishedText)
                            .font(.callout)
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 80, maxHeight: 160)
        }
    }

    private var footer: some View {
        HStack {
            Button("Cancel") { viewModel.cancel() }
                .keyboardShortcut(.cancelAction)
            Spacer()
            Button {
                viewModel.regenerate()
            } label: {
                Label("Regenerate", systemImage: "arrow.clockwise")
            }
            .disabled(viewModel.isWorking)

            Button {
                viewModel.accept()
            } label: {
                Label("Replace", systemImage: "checkmark")
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(!viewModel.canAccept)
        }
    }
}
