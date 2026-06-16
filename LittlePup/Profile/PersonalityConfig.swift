// PersonalityConfig.swift – per-pet personality traits that shape the auto-cycle behaviour

import Foundation // TimeInterval and Codable require Foundation

// Defines how a specific pet behaves in the idle/sleep/run auto-cycle.
// All fields are optional: absent values fall back to code defaults at runtime.
struct PersonalityConfig: Codable {
    // Human-readable blurb shown at the top of the right-click Dock menu
    let description: String
    // Seconds the pet runs when the auto-cycle picks run; nil → random 5–8 s at runtime
    let runDuration: TimeInterval?
    // Relative weight for idle in the auto-cycle picker; nil → 2
    let idleWeight: Int?
    // Relative weight for sleep in the auto-cycle picker; nil → 2
    let sleepWeight: Int?
    // Relative weight for run in the auto-cycle picker; nil → 1
    let runWeight: Int?
}
