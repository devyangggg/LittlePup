// PetState.swift – canonical vocabulary of behavioral/animation states shared by the whole app

import Foundation // String raw value and Codable conformance require Foundation

// All states the pet can visually be in; raw value is the JSON key used in profile lookups
enum PetState: String, Codable, CaseIterable {
    case idle   // default resting animation; every transition eventually returns here
    case walk   // pet crosses the screen in a transparent overlay window
    case run    // faster movement; auto-scheduled from walk/idle, no Dock menu item
    case sit    // pet sits quietly; auto-scheduled or triggered by the Dock menu
    case sleep  // longer-duration rest; lower frequency weight in the scheduler
    case eat    // interrupt-only; triggered by file drop or Feed menu, never auto-scheduled
    case bark   // one-shot reaction; triggered by Bark menu item, never auto-scheduled
}
