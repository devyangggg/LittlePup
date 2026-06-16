// AppDelegate.swift – thin AppKit adapter; receives OS lifecycle events and will forward to AppEnvironment

import AppKit // NSApplicationDelegate protocol is part of AppKit

// @MainActor: all NSApplicationDelegate callbacks fire on the main thread; this annotation
// makes that contract explicit and allows calling other @MainActor types (e.g. DockRenderer)
@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {

    // Kept alive for the process lifetime; will be replaced by AppEnvironment in a later step
    private var renderer: DockRenderer?

    // Called once, after the app's run loop starts but before any UI is displayed
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Step 4: push idle frame 0 to the Dock icon immediately so it animates from the first beat
        showStaticIdleFrame()
        // Future steps replace this with: environment = try AppEnvironment(); environment.start()
    }

    // Called just before the process exits; used for persistence in Step 11
    func applicationWillTerminate(_ notification: Notification) {
        // Step 11: will call environment.petController.shutdown() here
    }

    // Returning false prevents macOS from trying to reopen a window when the Dock icon is clicked
    func applicationShouldHandleReopen(_ sender: NSApplication,
                                       hasVisibleWindows flag: Bool) -> Bool {
        // We intentionally have no windows; ignore the reopen request
        return false
    }

    // Provides the right-click Dock menu; wired to DockMenuBuilder in Step 7
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        // Step 7: will return DockMenuBuilder().build() here
        return nil
    }

    // Modern file-drop hook (macOS 10.13+); called when files are dropped onto the Dock icon
    func application(_ application: NSApplication, open urls: [URL]) {
        // Step 15: will route through FileDropHandler via PetController
    }

    // Legacy file-drop hook; acts as a safety net for older launch-service paths
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        // Step 15: will delegate to the modern path then call replyToOpenOrPrint
        sender.reply(toOpenOrPrint: .success)
    }

    // MARK: – Step 4 helper (replaced by AnimationController in Step 5)

    // Load the profile, slice idle frame 0, and push it to the Dock icon
    private func showStaticIdleFrame() {
        // Decode the bundled JSON profile so we know the correct row and frameSize
        let loader = PetProfileLoader(bundle: .main, fileManager: .default)
        guard let profile = try? loader.loadDefaultProfile() else {
            // If the profile is missing or invalid, the bundle's static icon remains visible
            print("LittlePup: could not load default profile – showing bundle icon")
            return
        }
        // Locate the sprite sheet PNG that sits alongside the JSON in the Pets/ folder reference
        guard let sheetURL = Bundle.main.url(forResource: "golden_retriever_sprites",
                                             withExtension: "png",
                                             subdirectory: "Pets"),
              let sheetImage = NSImage(contentsOf: sheetURL) else {
            print("LittlePup: could not load sprite sheet – showing bundle icon")
            return
        }
        // Build the sprite sheet slicer using the frameSize from the profile
        let sheet = SpriteSheet(image: sheetImage, frameSize: profile.frameSize)
        // Retrieve the AnimationConfig for idle so we know which row to slice from
        guard let idleConfig = profile.animation(for: .idle) else {
            print("LittlePup: no idle animation in profile – showing bundle icon")
            return
        }
        // Slice only frame 0 of the idle row; AnimationController will cycle all frames in Step 5
        let idleFrame0 = sheet.frame(row: idleConfig.row, index: 0)
        // Create the renderer and push the frame; keep the renderer alive via the property
        let r = DockRenderer(application: .shared)
        r.render(idleFrame0)
        renderer = r
    }
}
