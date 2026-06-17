// UpdateChecker.swift – manual "Check for Updates…" against the latest GitHub release

import AppKit // NSAlert / NSWorkspace for the UI and download action

// Performs a one-shot update check when the user picks "Check for Updates…" from the Dock menu.
// Compares the running app's CFBundleShortVersionString to the latest GitHub release tag and,
// if a newer version exists, offers to download the new DMG. Manual only — no background polling.
@MainActor final class UpdateChecker: NSObject {

    // Repository the releases live in
    private static let repo = "devyangggg/LittlePup"
    // GitHub API endpoint for the most recent published release
    private static let apiURL = URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!
    // Permalink that always redirects to the newest release's DMG asset
    private static let dmgURL = URL(string: "https://github.com/\(repo)/releases/latest/download/LittlePup.dmg")!
    // Human-facing releases page, used as a fallback when the check fails
    private static let releasesURL = URL(string: "https://github.com/\(repo)/releases/latest")!

    // Minimal decode target; we only need the tag (e.g. "v1.0.2")
    private struct Release: Decodable { let tag_name: String }

    // The current app version string, e.g. "1.0.2"; falls back to "0.0.0" if somehow absent
    private var currentVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0.0"
    }

    // Entry point invoked by the Dock menu closure
    func check() {
        var request = URLRequest(url: Self.apiURL)
        // GitHub's API requires a User-Agent and recommends an explicit Accept header
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("LittlePup", forHTTPHeaderField: "User-Agent")
        // Don't serve a stale cached response for an update check
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let local = currentVersion
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            // Decode off the main thread, then hop back for all UI
            let latest = Self.parseTag(data: data, response: response, error: error)
            Task { @MainActor in
                guard let self else { return }
                guard let latest else { self.showError(); return }
                if Self.isNewer(latest, than: local) {
                    self.showUpdateAvailable(latest: latest, current: local)
                } else {
                    self.showUpToDate(current: local)
                }
            }
        }.resume()
    }

    // MARK: – Networking result parsing (pure; main-thread-agnostic)

    // Returns the release tag (e.g. "v1.0.2") on a successful 2xx JSON response, else nil
    private static func parseTag(data: Data?, response: URLResponse?, error: Error?) -> String? {
        guard error == nil,
              let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let data,
              let release = try? JSONDecoder().decode(Release.self, from: data)
        else { return nil }
        return release.tag_name
    }

    // True if remote is a strictly higher semantic version than local.
    // Strips a leading "v", compares dot-separated integer components, padding the shorter side.
    static func isNewer(_ remote: String, than local: String) -> Bool {
        let r = components(remote)
        let l = components(local)
        let count = max(r.count, l.count)
        for i in 0..<count {
            let rv = i < r.count ? r[i] : 0
            let lv = i < l.count ? l[i] : 0
            if rv != lv { return rv > lv }
        }
        return false
    }

    // Split a version string into integer components, ignoring a leading "v" and any non-numeric suffix
    private static func components(_ s: String) -> [Int] {
        let trimmed = s.hasPrefix("v") ? String(s.dropFirst()) : s
        return trimmed.split(separator: ".").map { Int($0.prefix(while: \.isNumber)) ?? 0 }
    }

    // MARK: – Alerts (main thread only)

    private func showUpdateAvailable(latest: String, current: String) {
        let alert = NSAlert()
        alert.messageText = "A new version of LittlePup is available"
        alert.informativeText = "Version \(latest) is available — you have \(current).\n\nDownload the new version, then drag it into your Applications folder to update."
        alert.addButton(withTitle: "Download")  // first button = default (Return)
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(Self.dmgURL)
        }
    }

    private func showUpToDate(current: String) {
        let alert = NSAlert()
        alert.messageText = "You're up to date"
        alert.informativeText = "LittlePup \(current) is the latest version."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func showError() {
        let alert = NSAlert()
        alert.messageText = "Couldn't check for updates"
        alert.informativeText = "Something went wrong reaching the update server. Please try again later, or visit the releases page."
        alert.addButton(withTitle: "Open Releases Page")
        alert.addButton(withTitle: "OK")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(Self.releasesURL)
        }
    }
}
