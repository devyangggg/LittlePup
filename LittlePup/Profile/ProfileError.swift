// ProfileError.swift – typed errors thrown by PetProfileLoader so callers can display clear messages

import Foundation // Error protocol requires Foundation

// All the ways loading a pet profile can fail, each carrying context for logging or display
enum ProfileError: Error {
    // No JSON file with the given name was found in any search location
    case fileNotFound(String)
    // The sprite sheet PNG referenced in the JSON does not exist alongside the JSON file
    case spriteSheetMissing(String)
    // The raw JSON bytes could not be decoded into PetProfile; the original error is preserved
    case decodeFailed(underlying: Error)
    // Decoded values violate constraints (e.g. frameCount ≤ 0, row out of sheet range, weight sum 0)
    case validationFailed(reason: String)
}
