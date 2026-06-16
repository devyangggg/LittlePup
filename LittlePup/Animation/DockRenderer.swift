// DockRenderer.swift – the sole writer of NSApplication.applicationIconImage; guarantees main-thread updates

import AppKit // NSApplication and NSImage live in AppKit

// Centralises all writes to applicationIconImage so no other code touches it directly.
// @MainActor enforces that every call happens on the main thread (required by AppKit).
@MainActor final class DockRenderer {

    // The shared application object whose Dock tile we update; injected for testability
    private let application: NSApplication

    // Inject NSApplication rather than using .shared directly so the class is unit-testable
    init(application: NSApplication) {
        self.application = application
    }

    // Push a new frame to the Dock tile; AppKit coalesces rapid writes automatically
    func render(_ image: NSImage) {
        // Setting applicationIconImage replaces the live Dock icon for this process
        application.applicationIconImage = image
    }

    // Restore the original bundle icon by setting applicationIconImage to nil
    func resetToBundleIcon() {
        // A nil assignment tells AppKit to revert to the static icon in the app bundle
        application.applicationIconImage = nil
    }
}
