// FrameClock.swift – NSTimer wrapper that fires in .common run-loop modes so animation survives menu tracking

import Foundation // Timer and RunLoop live in Foundation

// Owns one repeating Timer and exposes a simple fps-based start/stop API.
// The critical detail: the timer is added to RunLoop.common, not the default mode, so it
// continues to fire while a Dock menu is open (the run loop switches to NSEventTrackingRunLoopMode
// during menu tracking — a default-mode timer would freeze the animation at that point).
final class FrameClock {

    // Caller-supplied closure invoked on the main thread every timer interval
    var onTick: (() -> Void)?

    // The active timer; nil when the clock is stopped
    private var timer: Timer?

    // Start (or restart) firing at the given frame rate; replaces any previously running timer
    func start(fps: Double) {
        // Cancel any existing timer before creating a new one to avoid double-firing
        stop()
        // Convert fps to the per-frame interval in seconds
        let interval = 1.0 / fps
        // Build the timer without scheduling it so we can attach it to RunLoop.common ourselves
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            // [weak self] prevents a retain cycle between the timer closure and FrameClock
            self?.onTick?()
        }
        // .common covers the default, tracking, and modal panel modes — animation keeps going
        // even when Dock menus are open or the user drags a window
        RunLoop.main.add(t, forMode: .common)
        // Retain the timer so we can invalidate it later
        timer = t
    }

    // Stop the timer immediately; safe to call when already stopped
    func stop() {
        // invalidate() removes the timer from the run loop and breaks the retain cycle
        timer?.invalidate()
        // Nil the reference so isRunning reflects the correct state
        timer = nil
    }

    // True while a timer is active; used by callers to guard redundant start/stop calls
    var isRunning: Bool { timer != nil }

    // Invalidate the timer on deallocation so no orphan callbacks fire after release
    deinit {
        timer?.invalidate()
    }
}
