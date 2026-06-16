// AnimationController.swift – owns the frame index, drives the clock, and pushes frames to the Dock

import AppKit // NSImage is needed for the currentFrameImage return type

// Notified when a looping animation completes one full cycle; used by PetController in Step 9
protocol AnimationControllerDelegate: AnyObject {
    // Called each time the animation wraps back to frame 0 during a looping play()
    func animationDidCompleteCycle(_ state: PetState)
}

// Drives frame-by-frame animation for one state at a time.
// @MainActor: all operations are driven by the main-thread run-loop timer and write to DockRenderer,
// which is also @MainActor; this annotation enforces that contract at compile time.
@MainActor final class AnimationController {

    // The sliced sprite sheet; provides pre-cached NSImages for each (row, index) position
    private let spriteSheet: SpriteSheet
    // The decoded profile; used to look up the row, frameCount, and fps for each PetState
    private let profile: PetProfile
    // The shared timer; its fps changes when the state changes
    private let clock: FrameClock
    // The sole writer of applicationIconImage; DockRenderer.render() is called every tick
    private let renderer: DockRenderer

    // Optional observer; PetController sets itself as delegate in Step 9
    weak var delegate: AnimationControllerDelegate?

    // The state currently being animated; read by PetController to guard transition logic
    private(set) var currentState: PetState = .idle

    // Pre-sliced frames for the current state; populated by play() before the first tick fires
    private var currentFrames: [NSImage] = []
    // Index into currentFrames that was last pushed to the Dock
    private var currentFrameIndex: Int = 0
    // True for continuous looping animations (idle/sit/sleep/walk); false for one-shot (eat)
    private var looping: Bool = true
    // Stored closure to call when a one-shot animation reaches its last frame
    private var oneshotCompletion: (() -> Void)?

    // Seconds to hold frame 0 between cycles; 0 means loop immediately with no pause
    private var cyclePause: TimeInterval = 0
    // One-shot timer that fires after cyclePause to restart the clock; nil when not pausing
    private var pauseTimer: Timer?

    // Designated initialiser; all dependencies injected for testability
    init(spriteSheet: SpriteSheet,
         profile: PetProfile,
         clock: FrameClock,
         renderer: DockRenderer) {
        self.spriteSheet = spriteSheet
        self.profile = profile
        self.clock = clock
        self.renderer = renderer
        // Wire the clock's callback to our tick() method.
        // The closure is non-actor (FrameClock stores it as () -> Void), but the timer always
        // fires on the main run loop, so assumeIsolated correctly asserts our actual context.
        clock.onTick = { [weak self] in
            MainActor.assumeIsolated {
                // [weak self] prevents FrameClock from keeping AnimationController alive
                self?.tick()
            }
        }
    }

    // Start playing state, looping continuously if loop is true.
    // cyclePause: seconds to hold frame 0 between cycles (0 = loop immediately, no gap).
    func play(_ state: PetState, loop: Bool, cyclePause: TimeInterval = 0) {
        // Cancel any in-progress between-cycle pause so the new state starts immediately
        cancelPauseTimer()
        // If the profile has no animation for this state, stay in the current state
        guard let config = profile.animation(for: state) else { return }
        // Update bookkeeping before showing any frames
        currentState = state
        currentFrameIndex = 0
        looping = loop
        self.cyclePause = cyclePause
        oneshotCompletion = nil
        // Pre-slice all frames for this state so tick() never stalls waiting for slice I/O
        currentFrames = spriteSheet.frames(row: config.row, count: config.frameCount)
        // Restart the clock at the state's declared fps
        clock.start(fps: config.fps)
        // Push frame 0 immediately — the first tick fires after one full interval,
        // so without this the Dock would show the previous frame for up to 1/fps seconds
        if !currentFrames.isEmpty {
            renderer.render(currentFrames[0])
        }
    }

    // Play state exactly once, then call completion (used for eat and future one-shot states)
    func playOnce(_ state: PetState, completion: (() -> Void)?) {
        // Call play() FIRST — it resets oneshotCompletion to nil as part of its bookkeeping
        play(state, loop: false)
        // Set the completion AFTER so play()'s nil-reset doesn't wipe it out before tick() fires
        oneshotCompletion = completion
    }

    // Stop the clock without changing the displayed frame; leaves the last frame visible
    func stop() {
        // Also cancel any pending between-cycle pause so no restart fires unexpectedly
        cancelPauseTimer()
        clock.stop()
    }

    // Return the frame image currently showing on the Dock; WalkOverlayView calls this each tick
    func currentFrameImage() -> NSImage? {
        // Guard against the period between init and the first play() call
        guard !currentFrames.isEmpty else { return nil }
        return currentFrames[currentFrameIndex]
    }

    // MARK: – Private

    // Advance one frame; called by FrameClock.onTick on every timer interval
    private func tick() {
        // Do nothing if play() has not yet been called
        guard !currentFrames.isEmpty else { return }
        // Compute what the next index would be
        let next = currentFrameIndex + 1
        if next >= currentFrames.count {
            // End of one complete cycle
            if looping {
                // Always land on frame 0 so the still pose is correct during any pause
                currentFrameIndex = 0
                renderer.render(currentFrames[0])
                delegate?.animationDidCompleteCycle(currentState)
                if cyclePause > 0 {
                    // Stop the frame clock; frame 0 stays visible during the rest period
                    clock.stop()
                    // Schedule a one-shot timer to restart the clock after the pause
                    schedulePauseTimer()
                }
                // If cyclePause == 0 the clock keeps running and the next tick fires immediately
            } else {
                // One-shot: stop the clock and fire the stored completion closure
                clock.stop()
                let completion = oneshotCompletion
                oneshotCompletion = nil   // clear before calling to prevent double-fire
                completion?()
            }
        } else {
            // Normal advance: show the next frame in sequence
            currentFrameIndex = next
            renderer.render(currentFrames[currentFrameIndex])
        }
    }

    // Schedule the between-cycle restart timer; uses .common modes so it fires during menu tracking
    private func schedulePauseTimer() {
        // Capture the fps before entering the closure so we don't need to look it up again
        guard let config = profile.animation(for: currentState) else { return }
        let fps = config.fps
        // Build a one-shot timer; [weak self] avoids a retain cycle
        let t = Timer(timeInterval: cyclePause, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                // Restart the frame clock at the original fps to begin the next blink cycle
                self?.clock.start(fps: fps)
            }
        }
        // .common keeps the timer alive during menu tracking, consistent with FrameClock's policy
        RunLoop.main.add(t, forMode: .common)
        pauseTimer = t
    }

    // Cancel and nil the pause timer; called whenever a new play() or stop() supersedes it
    private func cancelPauseTimer() {
        pauseTimer?.invalidate()
        pauseTimer = nil
    }
}
