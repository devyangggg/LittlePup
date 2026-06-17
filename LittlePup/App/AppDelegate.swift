// AppDelegate.swift – thin AppKit adapter; receives OS lifecycle events and will forward to AppEnvironment

import AppKit // NSApplicationDelegate protocol is part of AppKit

// @MainActor: all NSApplicationDelegate callbacks fire on the main thread; this annotation
// makes that contract explicit and allows calling other @MainActor types (e.g. DockRenderer)
@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {

    // Holds the full animation stack alive for the process lifetime; replaced by AppEnvironment later
    private var animationController: AnimationController?
    // Loaded profile; kept alive so the auto-cycle can read personality weights at runtime
    private var petProfile: PetProfile?
    // Builds the right-click Dock menu; retained here so NSMenuItem.target (which points to it) stays valid
    private var dockMenuBuilder: DockMenuBuilder?
    // Performs the manual "Check for Updates…" action; retained so menu closures stay valid
    private var updateChecker: UpdateChecker?
    // Pending 3-minute cycle timer; cancelled on termination
    private var autoSwitchTimer: Timer?
    // Pending run-duration timer; fires when a timed run finishes to pick the next state
    private var runTimer: Timer?

    // Called once after the run loop starts; all UI setup goes here
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Step 5: start looping the idle animation immediately on the Dock icon
        startIdleAnimation()
        // Future steps replace this body with: environment = try? AppEnvironment()
    }

    // Called just before the process exits; used for persistence in Step 11
    func applicationWillTerminate(_ notification: Notification) {
        // Cancel both timers so no callbacks fire during teardown
        autoSwitchTimer?.invalidate()
        runTimer?.invalidate()
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
        // Only react to a file named food.png; any other drop is silently ignored
        guard urls.contains(where: { $0.lastPathComponent.lowercased() == "food.png" }),
              let controller = animationController else { return }
        feedPet(controller: controller)
    }

    // Legacy file-drop hook; acts as a safety net for older launch-service paths
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        // Mirror the modern hook: look for food.png in the filename list
        if filenames.contains(where: { ($0 as NSString).lastPathComponent.lowercased() == "food.png" }),
           let controller = animationController {
            feedPet(controller: controller)
        }
        // Always reply so Launch Services doesn't hang waiting for a response
        sender.reply(toOpenOrPrint: .success)
    }

    // Play the eat animation once then return to idle; shared by both drop hooks
    private func feedPet(controller: AnimationController) {
        controller.playOnce(.eat) {
            controller.play(.idle, loop: true, cyclePause: 4.0)
        }
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
        // Retain the profile so personality weights are available throughout the session
        petProfile = profile

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
        // Begin looping idle: blink through all frames, hold still for 4 s, then blink again
        controller.play(.idle, loop: true, cyclePause: 4.0)
        // Retain the controller; it owns clock and renderer so one reference keeps everything alive
        animationController = controller

        // Build the Dock menu with the pet's name and personality description as a header
        wireDockMenu(controller: controller, profile: profile)
        // Start the 3-minute idle/sleep/run auto-cycle
        startAutoCycle(controller: controller)
    }

    // MARK: – 3-state weighted auto-cycle

    // Kick off the first automatic cycle; the chain reschedules itself indefinitely
    private func startAutoCycle(controller: AnimationController) {
        scheduleNextCycle(controller: controller)
    }

    // Schedule one cycle tick after a ~3-minute random interval
    private func scheduleNextCycle(controller: AnimationController) {
        // Vary between 2.5 and 3.5 minutes so the transitions feel organic
        let interval = TimeInterval.random(in: 150...210)
        let t = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                // Pick and play the next state; run has its own timed follow-up
                let next = self.pickCycleState()
                self.playCycleState(next, controller: controller)
            }
        }
        // .common keeps the timer alive while Dock menus are open
        RunLoop.main.add(t, forMode: .common)
        autoSwitchTimer = t
    }

    // Choose idle, sleep, or run weighted by personality; defaults to 2/2/1 when no personality set
    private func pickCycleState() -> PetState {
        // Read weights from the loaded profile, falling back to neutral defaults
        let idleW  = petProfile?.personality?.idleWeight  ?? 2
        let sleepW = petProfile?.personality?.sleepWeight ?? 2
        let runW   = petProfile?.personality?.runWeight   ?? 1
        // Total the weights so we can roll a proportional random number
        let total  = idleW + sleepW + runW
        let roll   = Int.random(in: 0..<total)
        // Map the roll to a state bucket
        if roll < idleW             { return .idle  }
        if roll < idleW + sleepW    { return .sleep }
        return .run
    }

    // Play the cycle state; for run, starts a capped timer then immediately picks the next state
    private func playCycleState(_ state: PetState, controller: AnimationController) {
        switch state {
        case .idle:
            // Return to the blink-and-hold loop; schedule the next cycle in ~3 minutes
            controller.play(.idle, loop: true, cyclePause: 4.0)
            scheduleNextCycle(controller: controller)

        case .sleep:
            // Slow breathing loop; schedule the next cycle in ~3 minutes
            controller.play(.sleep, loop: true, cyclePause: 3.0)
            scheduleNextCycle(controller: controller)

        case .run:
            // Cap run to personality.runDuration (Cherry: 12 s) or random 5–8 s for others
            let duration = petProfile?.personality?.runDuration
                           ?? TimeInterval.random(in: 5...8)
            controller.play(.run, loop: true)
            // After the duration, stop running and immediately pick the next state
            let rt = Timer(timeInterval: duration, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    let next = self.pickCycleState()
                    self.playCycleState(next, controller: controller)
                }
            }
            RunLoop.main.add(rt, forMode: .common)
            runTimer = rt
            // The outer cycle timer is not rescheduled here; playCycleState re-enters after run ends

        default:
            // Should never be reached; fall back to idle safely
            controller.play(.idle, loop: true, cyclePause: 4.0)
            scheduleNextCycle(controller: controller)
        }
    }

    // MARK: – Dock menu

    // Create DockMenuBuilder with one closure per menu item; replaced by PetController in Step 9
    private func wireDockMenu(controller: AnimationController, profile: PetProfile) {
        // Create and retain the update checker; the checkUpdates closure captures it
        let checker = UpdateChecker()
        updateChecker = checker
        // Each closure captures controller with a strong reference; controller is already retained
        // by animationController above, so this adds no ownership cycle
        let actions = DockMenuActions(
            idle: {
                // Resume the blink-and-hold loop from any other state
                controller.play(.idle, loop: true, cyclePause: 4.0)
            },
            sit: {
                // Blink through all sit frames, hold still for 4 s, then blink again — same rhythm as idle
                controller.play(.sit, loop: true, cyclePause: 4.0)
            },
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
                    controller.play(.idle, loop: true, cyclePause: 4.0)
                }
            },
            bark: {
                // Play bark exactly once, then restore the idle blink-and-hold loop
                controller.playOnce(.bark) {
                    controller.play(.idle, loop: true, cyclePause: 4.0)
                }
            },
            checkUpdates: {
                // Query GitHub for a newer release and, if found, offer to download the DMG
                checker.check()
            }
        )
        // Build and retain the builder; NSMenuItem.target points at it, so it must outlive the menu
        dockMenuBuilder = DockMenuBuilder(petName: profile.name,
                                          petDescription: profile.personality?.description,
                                          actions: actions)
    }
}
