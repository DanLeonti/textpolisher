import UIKit
import SwiftUI
import UniformTypeIdentifiers

/// Principal class for the Action Extension. It runs when the user selects text
/// in another app and taps the "Polish" action in the Share Sheet. It reads the
/// selected text, hosts the SwiftUI `ActionView`, and - if the user taps
/// "Replace" - returns the polished text so a host that accepts edits swaps the
/// selection in place.
final class ActionViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        Task { await loadAndPresent() }
    }

    private func loadAndPresent() async {
        let selected = await loadSelectedText() ?? ""

        let model = ActionModel(
            original: selected,
            onCancel: { [weak self] in self?.cancel() },
            onReplace: { [weak self] polished in self?.complete(with: polished) }
        )

        let host = UIHostingController(rootView: ActionView(model: model))
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        host.didMove(toParent: self)

        model.start()
    }

    private func loadSelectedText() async -> String? {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem else { return nil }
        for provider in item.attachments ?? [] {
            guard provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) else { continue }
            if let value = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier),
               let text = value as? String {
                return text
            }
        }
        return nil
    }

    private func complete(with polished: String) {
        let output = NSExtensionItem()
        output.attachments = [
            NSItemProvider(item: polished as NSString, typeIdentifier: UTType.plainText.identifier)
        ]
        extensionContext?.completeRequest(returningItems: [output])
    }

    private func cancel() {
        extensionContext?.cancelRequest(
            withError: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError)
        )
    }
}
