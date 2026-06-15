// AnimationConfig.swift – per-animation layout config decoded from the "animations" block of a profile JSON

import Foundation // Codable requires Foundation for JSONDecoder support

// One entry in the "animations" dictionary; keyed by PetState.rawValue in the JSON
struct AnimationConfig: Codable {
    // Zero-based row index into the sprite sheet; row 0 is the topmost strip of the PNG
    let row: Int
    // Number of horizontal frames in this animation row; must be >= 1 and fit the sheet width
    let frameCount: Int
    // Playback rate in frames per second; governs the FrameClock interval for this state
    let fps: Double
}
