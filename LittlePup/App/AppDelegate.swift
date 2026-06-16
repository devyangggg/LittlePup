// AppDelegate.swift – thin AppKit adapter; receives OS lifecycle events and will forward to AppEnvironment

import AppKit // NSApplicationDelegate protocol is part of AppKit

// @MainActor: all NSApplicationDelegate callbacks fire on the main thread; this annotation
// makes that contract explicit and allows calling other @MainActor types (e.g. DockRenderer)
@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {

    // Holds the full animation stack alive for the process lifetime; replaced by AppEnvironment later
    private var animationController: AnimationController?
    // Builds the right-click Dock menu; retained here so NSMenuItem.target (which points to it) stays valid
    private var dockMenuBuilder: DockMenuBuilder?

    // Called once after the run loop starts; all UI setup goes here
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Step 5: start looping the idle animation immediately on the Dock icon
        startIdleAnimation()
        // Future steps replace this body with: environment = try? AppEnvironment()
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

    // Provides the right-click Dock menu; AppKit calls this each time the user right-clicks the Dock icon
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        // Return a fresh menu each call; AppKit discards the previous NSMenu automatically
        return dockMenuBuilder?.build()
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

    // MARK: – Step 5 helper (replaced by PetController.start() in Step 9)

    // Build the full animation stack and begin looping the idle animation on the Dock
    private func startIdleAnimation() {
        // Decode the bundled golden retriever profile (row/frameCount/fps for each state)
        let loader = PetProfileLoader(bundle: .main, fileManager: .default)
        guard let profile = try? loader.loadDefaultProfile() else {
            // If the profile is missing the app falls back to the static bundle icon
            print("LittlePup: could not load default profile")
            return
        }
        // Load the sprite sheet PNG from the Pets/ folder reference inside the app bundle
        guard let sheetURL = Bundle.main.url(forResource: "golden_retriever_sprites",
                                             withExtension: "png",
                                             subdirectory: "Pets"),
              let sheetImage = NSImage(contentsOf: sheetURL) else {
            print("LittlePup: could not load sprite sheet")
            return
        }
        // Create the sprite sheet slicer with the frame size from the decoded profile
        let sheet = SpriteSheet(image: sheetImage, frameSize: profile.frameSize)
        // Create a shared clock; AnimationController changes its fps when the state changes
        let clock = FrameClock()
        // Create the renderer; all applicationIconImage writes go through this one object
        let renderer = DockRenderer(application: .shared)
        // Wire everything together; AnimationController sets clock.onTick in its init
        let controller = AnimationController(spriteSheet: sheet,
                                             profile: profile,
                                             clock: clock,
                                             renderer: renderer)
        // Begin looping idle: blink through all 4 frames, hold still for 2 s, then blink again
        controller.play(.idle, loop: true, cyclePause: 2.0)
        // Retain the controller; it owns clock and renderer so one reference keeps everything alive
        animationController = controller

        // Step 7: build the Dock menu and wire each item to the animation controller
        wireDockMenu(controller: controller)
    }

    // Create DockMenuBuilder with one closure per menu item; replaced by PetController in Step 9
    private func wireDockMenu(controller: AnimationController) {
        // Each closure captures controller with a strong reference; controller is already retained
        // by animationController above, so this adds no ownership cycle
        let actions = DockMenuActions(
            sleep: {
                // Hold on frame 0 for 3 s between breathing cycles so the rhythm feels natural
                controller.play(.sleep, loop: true, cyclePause: 3.0)
            },
            walk: {
                // Loop walk animation on the Dock tile (overlay window added in Step 12)
                controller.play(.walk, loop: true)
            },
            feed: {
                // Play eat exactly once, then restore the idle blink-and-hold loop
                controller.playOnce(.eat) {
                    controller.play(.idle, loop: true, cyclePause: 2.0)
                }
            }
        )
        // Build and retain the builder; NSMenuItem.target points at it, so it must outlive the menu
        dockMenuBuilder = DockMenuBuilder(actions: actions)
    }
}
