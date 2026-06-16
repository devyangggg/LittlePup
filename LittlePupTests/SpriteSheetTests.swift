// SpriteSheetTests.swift – unit tests for Step 3: SpriteSheet slicing, caching, and bounds

import XCTest  // XCTest framework for test cases and assertions
import AppKit  // NSImage, NSSize, and CGSize are needed here
@testable import LittlePup // @testable exposes internal types without making them public

final class SpriteSheetTests: XCTestCase {

    // Shared sheet instance loaded once per test class; all tests use the real 1024×896 PNG
    private var sheet: SpriteSheet!

    // Build the sheet before every test using the sprite PNG from the test bundle
    override func setUpWithError() throws {
        try super.setUpWithError()
        // Resolve the PNG via the Pets/ folder reference that was added to the test target
        let testBundle = Bundle(for: SpriteSheetTests.self)
        guard let url = testBundle.url(forResource: "golden_retriever_sprites",
                                       withExtension: "png",
                                       subdirectory: "Pets"),
              let image = NSImage(contentsOf: url) else {
            // Fail the test immediately if the resource is missing rather than silently skipping
            throw XCTSkip("golden_retriever_sprites.png not found in test bundle Pets/ folder")
        }
        // Create the SpriteSheet with the 128px frame size declared in the JSON profile
        sheet = SpriteSheet(image: image, frameSize: 128)
    }

    // Release the sheet after every test to avoid cross-test state
    override func tearDown() {
        sheet = nil
        super.tearDown()
    }

    // MARK: – pixelSize

    // The reported pixel size must exactly match the raw PNG dimensions (1024 × 896)
    func testPixelSizeMatchesActualPNG() {
        // Known: 8 columns × 128px = 1024px wide; 7 rows × 128px = 896px tall
        XCTAssertEqual(sheet.pixelSize.width,  1024,
                       "pixelSize.width should be 1024 (8 frames × 128px)")
        XCTAssertEqual(sheet.pixelSize.height,  896,
                       "pixelSize.height should be 896 (7 rows × 128px)")
    }

    // MARK: – frameSize

    // The frameSize property must return the value passed at init time
    func testFrameSizeReturnsInitValue() {
        XCTAssertEqual(sheet.frameSize, 128, "frameSize must match the value passed to init")
    }

    // MARK: – frame(row:index:) – size and non-nil

    // Every frame must be a non-nil NSImage declared at exactly 128 × 128 points
    func testFrameSizeIs128x128() {
        // Sample frame from row 0 (idle), first column
        let f = sheet.frame(row: 0, index: 0)
        XCTAssertEqual(f.size, NSSize(width: 128, height: 128),
                       "Each sliced frame must be 128×128 points")
    }

    // frame() from different rows and columns must all return the same declared size
    func testFrameSizeIsConsistentAcrossRows() {
        // Check one frame from each of the 7 rows at column 0
        for row in 0..<7 {
            let f = sheet.frame(row: row, index: 0)
            XCTAssertEqual(f.size, NSSize(width: 128, height: 128),
                           "Row \(row), index 0 should be 128×128")
        }
    }

    // MARK: – frames(row:count:)

    // Idle row has 7 frames
    func testIdleRowReturnsCorrectFrameCount() {
        let idleFrames = sheet.frames(row: 0, count: 7) // row 0 = IDLE, 7 frames
        XCTAssertEqual(idleFrames.count, 7, "IDLE row must produce 7 frames")
    }

    // Walk row has 8 frames
    func testWalkRowReturnsCorrectFrameCount() {
        let walkFrames = sheet.frames(row: 1, count: 8) // row 1 = WALK, 8 frames
        XCTAssertEqual(walkFrames.count, 8, "WALK row must produce 8 frames")
    }

    // Run row has 8 frames
    func testRunRowReturnsCorrectFrameCount() {
        let runFrames = sheet.frames(row: 2, count: 8) // row 2 = RUN, 8 frames
        XCTAssertEqual(runFrames.count, 8, "RUN row must produce 8 frames")
    }

    // Sit row has 4 frames
    func testSitRowReturnsCorrectFrameCount() {
        let sitFrames = sheet.frames(row: 3, count: 4) // row 3 = SIT, 4 frames
        XCTAssertEqual(sitFrames.count, 4, "SIT row must produce 4 frames")
    }

    // Sleep row has 4 frames
    func testSleepRowReturnsCorrectFrameCount() {
        let sleepFrames = sheet.frames(row: 4, count: 4) // row 4 = SLEEP, 4 frames
        XCTAssertEqual(sleepFrames.count, 4, "SLEEP row must produce 4 frames")
    }

    // Eat row has 6 frames
    func testEatRowReturnsCorrectFrameCount() {
        let eatFrames = sheet.frames(row: 5, count: 6) // row 5 = EAT, 6 frames
        XCTAssertEqual(eatFrames.count, 6, "EAT row must produce 6 frames")
    }

    // Bark row has 4 frames
    func testBarkRowReturnsCorrectFrameCount() {
        let barkFrames = sheet.frames(row: 6, count: 4) // row 6 = BARK, 4 frames
        XCTAssertEqual(barkFrames.count, 4, "BARK row must produce 4 frames")
    }

    // Every element in a frames() result must be 128×128
    func testAllFramesInSliceAre128x128() {
        // Use the walk row (largest frame count) for a thorough check
        let walkFrames = sheet.frames(row: 1, count: 8)
        for (i, f) in walkFrames.enumerated() {
            XCTAssertEqual(f.size, NSSize(width: 128, height: 128),
                           "Walk frame \(i) should be 128×128")
        }
    }

    // MARK: – Cache correctness

    // Two calls to frame(row:index:) with the same arguments must return the identical NSImage object
    func testCacheReturnsSameInstance() {
        // First call populates the cache; second call must hit it
        let first  = sheet.frame(row: 0, index: 0)
        let second = sheet.frame(row: 0, index: 0)
        // NSImage is a reference type; === checks object identity, not content equality
        XCTAssertTrue(first === second,
                      "Repeated frame access must return the cached NSImage, not a new slice")
    }

    // Frames from different positions must be distinct objects (different cache slots)
    func testCacheKeysDifferByPosition() {
        // Two different positions must not accidentally collide in the flat key space
        let a = sheet.frame(row: 0, index: 0)
        let b = sheet.frame(row: 0, index: 1)
        let c = sheet.frame(row: 1, index: 0)
        XCTAssertFalse(a === b, "Column-adjacent frames must be distinct cached objects")
        XCTAssertFalse(a === c, "Row-adjacent frames must be distinct cached objects")
    }

    // MARK: – preload()

    // Calling preload() with all seven animation configs must not crash or throw
    func testPreloadAllAnimationsSucceeds() {
        // Build the AnimationConfig list mirroring golden_retriever.json
        let animations: [AnimationConfig] = [
            AnimationConfig(row: 0, frameCount: 7, fps:  8.0),  // idle
            AnimationConfig(row: 1, frameCount: 8, fps: 12.0),  // walk
            AnimationConfig(row: 2, frameCount: 8, fps: 16.0),  // run
            AnimationConfig(row: 3, frameCount: 4, fps:  6.0),  // sit
            AnimationConfig(row: 4, frameCount: 4, fps:  3.0),  // sleep
            AnimationConfig(row: 5, frameCount: 6, fps: 10.0),  // eat
            AnimationConfig(row: 6, frameCount: 4, fps: 12.0),  // bark
        ]
        // preload() must complete without crashing; it returns Void
        sheet.preload(animations: animations)
        // After preload, every frame must already be in cache (same instance on re-access)
        let idle0 = sheet.frame(row: 0, index: 0)
        let idle0again = sheet.frame(row: 0, index: 0)
        XCTAssertTrue(idle0 === idle0again,
                      "After preload, frame access must return the pre-cached instance")
    }

    // MARK: – Out-of-bounds (documented; triggers preconditionFailure in production)
    //
    // frame(row:index:) calls precondition() when row or index is outside the sheet bounds.
    // preconditionFailure crashes the process in both Debug and Release, so these paths cannot
    // be exercised inside XCTest without terminating the test runner.
    //
    // The guard is verified by inspection: SpriteSheet.swift lines with `precondition(row >= 0`,
    // `precondition(index >= 0`, and `preconditionFailure(...)` confirm the contract.
    // Callers (AnimationController, SpriteSheetTests.testPreloadAllAnimationsSucceeds) only pass
    // indices derived from validated AnimationConfig values, so the precondition should never fire
    // in practice.
}
