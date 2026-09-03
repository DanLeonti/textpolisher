import Foundation

/// Manual, user-initiated update check. Fetches a small JSON manifest describing
/// the latest released version and compares it to the running build. This is the
/// only thing in the app that touches the network, and it fires solely when the
/// user clicks "Check for Updates…" — never automatically — so the on-device,
/// nothing-leaves-your-Mac promise of the polishing flow is preserved.
enum UpdateChecker {
    static let manifestURL = URL(string: "https://dl.textpolisher.app/appcast.json")!
    static let websiteURL = URL(string: "https://textpolisher.app")!

    struct Manifest: Decodable {
        let version: String
        let url: String
        let notes: String?
    }

    enum Result {
        case upToDate(current: String)
        case updateAvailable(latest: String, current: String, downloadURL: URL, notes: String?)
        case failed(String)
    }

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    static func check() async -> Result {
        let current = currentVersion
        do {
            var request = URLRequest(url: manifestURL)
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            request.timeoutInterval = 15
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return .failed("The update server returned an unexpected response.")
            }
            let manifest = try JSONDecoder().decode(Manifest.self, from: data)
            guard let downloadURL = URL(string: manifest.url) else {
                return .failed("The update information was malformed.")
            }
            if isNewer(manifest.version, than: current) {
                return .updateAvailable(latest: manifest.version, current: current,
                                        downloadURL: downloadURL, notes: manifest.notes)
            }
            return .upToDate(current: current)
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// Compares dotted numeric versions ("1.0", "1.2.3") component by component.
    /// Missing trailing components are treated as 0, so "1.1" > "1.0" and
    /// "1.1.0" == "1.1".
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let lhs = components(candidate)
        let rhs = components(current)
        for index in 0..<max(lhs.count, rhs.count) {
            let a = index < lhs.count ? lhs[index] : 0
            let b = index < rhs.count ? rhs[index] : 0
            if a != b { return a > b }
        }
        return false
    }

    private static func components(_ version: String) -> [Int] {
        version.split(separator: ".").map { Int($0.filter(\.isNumber)) ?? 0 }
    }
}
