// BehaviorConfig.swift – scheduling rules per state; decoded from the "behaviors" block of a profile JSON

import Foundation // TimeInterval and Codable require Foundation

// One candidate in the nextStates array; WeightedPicker uses these to choose the following state
struct WeightedState: Codable {
    // The state this entry can transition the pet into
    let state: PetState
    // Relative probability weight; higher values make this candidate more likely to win
    let weight: Int
}

// Scheduling parameters for one state; controls dwell time and what state follows
struct BehaviorConfig: Codable {
    // Minimum seconds the pet spends in this state before the scheduler fires
    let minDuration: TimeInterval
    // Maximum seconds the pet spends in this state; must be >= minDuration
    let maxDuration: TimeInterval
    // Candidate next states with relative weights; total weight sum must be > 0
    let nextStates: [WeightedState]
}
