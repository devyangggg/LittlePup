// PetProfileLoader.swift – locates, decodes, and validates a pet profile JSON + sprite sheet PNG

import AppKit // NSImage is needed to read the sprite sheet's pixel dimensions for validation

// Finds JSON in the bundle (Resources/Pets/) or user Application Support, decodes it, validates it
struct PetProfileLoader {
    // Bundle to search first; inject test bundle in unit tests, app bundle in production
    let bundle: Bundle
    // FileManager for existence checks and user-directory lookups; injectable for testing
    let fileManager: FileManager

    // Designated initializer; all dependencies injected so the loader is testable without a real app
    init(bundle: Bundle, fileManager: FileManager) {
        self.bundle = bundle
        self.fileManager = fileManager
    }

    // Load a profile by its snake_case id; bundle takes priority over the user packs directory
    func loadProfile(named name: String) throws -> PetProfile {
        // Locate the JSON file on disk (throws .fileNotFound if neither location has it)
        let jsonURL = try findJSONURL(named: name)
        // Parse the JSON bytes into a typed PetProfile value (throws .decodeFailed on bad JSON)
        let profile = try decodeProfile(at: jsonURL)
        // Confirm the sprite sheet PNG is present alongside the JSON (throws .spriteSheetMissing)
        let sheetURL = try resolveSpriteSheetURL(for: profile, alongside: jsonURL)
        // Read the actual pixel dimensions so validate() can check row/frame counts against them
        let sheetSize = try pixelSize(of: sheetURL)
        // Reject profiles whose declared frame geometry exceeds the actual sheet (throws .validationFailed)
        try validate(profile, sheetPixelSize: sheetSize)
        // Return the fully-validated profile to the caller
        return profile
    }

    // Convenience: load the bundled starter profile without specifying its name
    func loadDefaultProfile() throws -> PetProfile {
        // "golden_retriever" is the hardcoded default; Step 11 will read the saved profileId instead
        return try loadProfile(named: "golden_retriever")
    }

    // Given the profile and the URL of its JSON, return the URL of the sprite sheet PNG
    func resolveSpriteSheetURL(for profile: PetProfile, alongside jsonURL: URL) throws -> URL {
        // Strip the JSON filename to get the directory that contains both the JSON and the PNG
        let dir = jsonURL.deletingLastPathComponent()
        // Append the sprite sheet filename declared in the JSON (e.g. "golden_retriever_sprites.png")
        let sheetURL = dir.appendingPathComponent(profile.spriteSheet)
        // Fail clearly if the PNG is missing rather than letting NSImage silently return nil later
        guard fileManager.fileExists(atPath: sheetURL.path) else {
            throw ProfileError.spriteSheetMissing(sheetURL.path)
        }
        return sheetURL
    }

    // Verify all frame geometry, fps, and behavior weight values are within legal ranges
    func validate(_ profile: PetProfile, sheetPixelSize: CGSize) throws {
        // frameSize <= 0 would produce division-by-zero or empty slices in SpriteSheet
        guard profile.frameSize > 0 else {
            throw ProfileError.validationFailed(reason: "frameSize must be > 0")
        }
        // Compute how many full rows and columns fit in the sheet at the declared frame size
        let sheetRows = Int(sheetPixelSize.height) / profile.frameSize
        let maxFrames = Int(sheetPixelSize.width)  / profile.frameSize
        // Validate every animation entry in the profile
        for (stateName, anim) in profile.animations {
            // frameCount=0 would produce a zero-length frame array in SpriteSheet
            guard anim.frameCount > 0 else {
                throw ProfileError.validationFailed(reason: "\(stateName): frameCount must be > 0")
            }
            // Non-positive fps would make the FrameClock interval zero or negative
            guard anim.fps > 0 else {
                throw ProfileError.validationFailed(reason: "\(stateName): fps must be > 0")
            }
            // A negative row index has no meaning in the sprite sheet coordinate system
            guard anim.row >= 0 else {
                throw ProfileError.validationFailed(reason: "\(stateName): row must be >= 0")
            }
            // Row index must not exceed the number of rows that actually fit in the sheet
            guard anim.row < sheetRows else {
                throw ProfileError.validationFailed(
                    reason: "\(stateName): row \(anim.row) is out of range (sheet has \(sheetRows) rows)")
            }
            // All frames for this animation must fit within the sheet width
            guard anim.frameCount <= maxFrames else {
                throw ProfileError.validationFailed(
                    reason: "\(stateName): frameCount \(anim.frameCount) exceeds sheet columns (max \(maxFrames))")
            }
        }
        // Validate scheduler parameters in the behaviors block, if present
        if let behaviors = profile.behaviors {
            for (stateName, behavior) in behaviors {
                // minDuration=0 would fire the scheduler timer immediately with no dwell time
                guard behavior.minDuration > 0 else {
                    throw ProfileError.validationFailed(reason: "\(stateName): minDuration must be > 0")
                }
                // maxDuration < minDuration makes randomDuration(min:max:) undefined
                guard behavior.maxDuration >= behavior.minDuration else {
                    throw ProfileError.validationFailed(
                        reason: "\(stateName): maxDuration must be >= minDuration")
                }
                // WeightedPicker requires at least one candidate or it always returns nil
                guard !behavior.nextStates.isEmpty else {
                    throw ProfileError.validationFailed(
                        reason: "\(stateName): nextStates must not be empty")
                }
                // Total weight of 0 means every candidate has weight 0; WeightedPicker can't pick
                let totalWeight = behavior.nextStates.reduce(0) { $0 + $1.weight }
                guard totalWeight > 0 else {
                    throw ProfileError.validationFailed(
                        reason: "\(stateName): sum of nextState weights must be > 0")
                }
            }
        }
    }

    // MARK: – Private helpers

    // Search for a JSON file by name; bundle (Resources/Pets/) takes priority over user directory
    private func findJSONURL(named name: String) throws -> URL {
        // Primary: look inside the bundle under Resources/Pets/ (folder-reference preserves the path)
        if let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "Pets") {
            return url
        }
        // Flat-bundle fallback: handles projects where Pets files were added as individual resources
        if let url = bundle.url(forResource: name, withExtension: "json") {
            return url
        }
        // Secondary: look in the user's Application Support directory for community packs
        let candidate = userPetsDirectory()
            .appendingPathComponent(name)             // …/LittlePup/pets/<name>/
            .appendingPathComponent(name + ".json")   // …/LittlePup/pets/<name>/<name>.json
        if fileManager.fileExists(atPath: candidate.path) {
            return candidate
        }
        // Neither search location contained the JSON file
        throw ProfileError.fileNotFound(name)
    }

    // Read the file at the given URL and decode it into a PetProfile value
    private func decodeProfile(at url: URL) throws -> PetProfile {
        // Read raw bytes; wrap any IO error as decodeFailed so callers see a ProfileError
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ProfileError.decodeFailed(underlying: error)
        }
        // Run the Codable decoder; wrap any JSON parse error the same way
        do {
            return try JSONDecoder().decode(PetProfile.self, from: data)
        } catch {
            throw ProfileError.decodeFailed(underlying: error)
        }
    }

    // Load an image and return its pixel dimensions (not AppKit point dimensions)
    private func pixelSize(of url: URL) throws -> CGSize {
        // NSImage returns nil for corrupt or unreadable files
        guard let image = NSImage(contentsOf: url) else {
            throw ProfileError.spriteSheetMissing(url.path)
        }
        // Use the first bitmap representation to read actual pixel counts, not scaled points
        if let rep = image.representations.first {
            return CGSize(width: CGFloat(rep.pixelsWide), height: CGFloat(rep.pixelsHigh))
        }
        // Fall back to the image's intrinsic size if no bitmap representation is available
        return image.size
    }

    // Construct the URL to the user's community pet pack folder in Application Support
    private func userPetsDirectory() -> URL {
        // Application Support is the macOS-standard location for user-installed app content
        let appSupport = fileManager.urls(for: .applicationSupportDirectory,
                                          in: .userDomainMask).first!
        // Nest under "LittlePup/pets" to keep our files isolated from other apps
        return appSupport
            .appendingPathComponent("LittlePup")
            .appendingPathComponent("pets")
    }
}
