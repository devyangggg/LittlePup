// PetProfile.swift – top-level Codable model; mirrors the pet pack JSON structure exactly

import Foundation // Codable and URL require Foundation

// Complete description of one pet: identity, sprite layout, and optional behavioral scheduler config
struct PetProfile: Codable {
    // Unique snake_case identifier matching the JSON filename stem (e.g. "golden_retriever")
    let id: String
    // Human-readable display name shown in UI (e.g. "Golden Retriever")
    let name: String
    // Filename of the sprite sheet PNG located alongside this JSON file on disk
    let spriteSheet: String
    // Pixel side length of each square frame; all rows and all states use the same size
    let frameSize: Int
    // Keyed by PetState.rawValue; contains animation config for every state the profile supports
    let animations: [String: AnimationConfig]
    // Optional; when absent the scheduler will not auto-cycle (purely manual pet)
    let behaviors: [String: BehaviorConfig]?
    // Optional personality traits; shapes the auto-cycle state picker and Dock menu header
    let personality: PersonalityConfig?

    // Return the animation config for the given state, or nil if the profile omits that state
    func animation(for state: PetState) -> AnimationConfig? {
        // PetState.rawValue is the JSON key (e.g. "idle", "walk")
        return animations[state.rawValue]
    }

    // Return the behavior scheduling config for the given state, or nil if absent
    func behavior(for state: PetState) -> BehaviorConfig? {
        // Returns nil if behaviors block is absent entirely, or if this state has no entry
        return behaviors?[state.rawValue]
    }
}
