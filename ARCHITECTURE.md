# LittlePup — Architecture & Build Plan

> Open source macOS Dock pet (Swift + AppKit, no SwiftUI, direct download, non-sandboxed).
> This document is the single source of truth handed to the implementation agent.
> **No implementation code lives here — structures, signatures, and sequencing only.**

---

## 0. Critical correction before anything is built

The brief says "App runs as a UI agent (no menu bar icon initially)" and the tech notes
imply `LSUIElement`. **Do not set `LSUIElement` / do not use activation policy `.accessory`.**

- An `LSUIElement` (agent) app has **no Dock icon at all**. The Dock icon *is the product*.
- The app **must** run as a regular app: `NSApplication.activationPolicy == .regular`.
- "No menu bar icon" means **do not create an `NSStatusItem`** (a menu-bar *extra*). That is
  unrelated to activation policy. A regular app will still own the top menu bar when focused —
  that is normal and acceptable for MVP.
- "Launches without showing a window" is achieved by **not creating a window** and **not
  shipping a main storyboard/nib** — no special plist key forces this.

Everything below assumes a regular, non-sandboxed, programmatically-launched AppKit app.

---

## 1. Full file & folder structure

```
LittlePup/
├── LittlePup.xcodeproj/
│
├── LittlePup/                          # App target source root
│   │
│   ├── App/
│   │   ├── main.swift                  # Programmatic entry point (no @main storyboard)
│   │   ├── AppDelegate.swift           # NSApplicationDelegate: lifecycle, dock menu, file-drop hooks
│   │   └── AppEnvironment.swift        # Composition root: builds & wires all controllers/services
│   │
│   ├── Core/
│   │   ├── PetState.swift              # enum of behavioral/animation states (idle/walk/sit/sleep/eat)
│   │   ├── PetController.swift         # Top-level orchestrator; owns scheduler + animation + walk
│   │   └── StateTransition.swift       # Value type describing a requested transition + its source
│   │
│   ├── Animation/
│   │   ├── AnimationController.swift   # Drives frame stepping, pushes frames to the Dock
│   │   ├── SpriteSheet.swift           # Slices the sprite PNG into per-(row,frame) NSImages
│   │   ├── FrameClock.swift            # NSTimer wrapper added to common run-loop modes
│   │   └── DockRenderer.swift          # Sole owner of NSApplication.applicationIconImage writes
│   │
│   ├── Behavior/
│   │   ├── BehaviorScheduler.swift     # Auto-cycling state machine; weighted random next-state
│   │   ├── BehaviorConfig.swift        # Decoded "behaviors" block (durations + weighted edges)
│   │   └── WeightedPicker.swift        # Pure helper: weighted random selection (seedable)
│   │
│   ├── Walking/
│   │   ├── WalkWindowController.swift  # Owns the transparent overlay NSWindow lifecycle
│   │   ├── WalkOverlayView.swift       # NSView that draws the current walk frame
│   │   └── WalkPathController.swift    # Computes screen-space path & per-tick position
│   │
│   ├── Profile/
│   │   ├── PetProfile.swift           # Decoded model: id/name/spriteSheet/frameSize/animations/behaviors
│   │   ├── AnimationConfig.swift      # Per-animation config (row, frameCount, fps)
│   │   ├── PetProfileLoader.swift     # Locates + decodes JSON, resolves sprite PNG, validates
│   │   └── ProfileError.swift         # Typed errors for malformed/missing profiles
│   │
│   ├── DragDrop/
│   │   └── FileDropHandler.swift      # Interprets dropped file paths; food.png rule; deletion
│   │
│   ├── Persistence/
│   │   └── StateStore.swift           # UserDefaults read/write of last state + active profile id
│   │
│   ├── Menu/
│   │   └── DockMenuBuilder.swift      # Builds the right-click NSMenu (Sit/Sleep/Walk/Feed)
│   │
│   ├── Resources/
│   │   ├── Pets/
│   │   │   ├── golden_retriever.json
│   │   │   └── golden_retriever_sprites.png   # (== dockdog_sprites_clean.png, renamed per profile)
│   │   └── Assets.xcassets/
│   │       └── AppIcon.appiconset/            # Static fallback bundle icon
│   │
│   └── Info.plist
│
├── LittlePupTests/                    # Unit tests (logic only — no AppKit UI)
│   ├── WeightedPickerTests.swift
│   ├── BehaviorSchedulerTests.swift
│   ├── PetProfileLoaderTests.swift
│   ├── SpriteSheetTests.swift
│   └── FileDropHandlerTests.swift
│
├── docs/
│   ├── PET_PACK_FORMAT.md
│   └── ARCHITECTURE.md                # (this file)
│
├── pets/                             # Community pet packs (outside app bundle, optional)
│   └── golden_retriever/
│       ├── golden_retriever.json
│       └── golden_retriever_sprites.png
│
├── README.md
├── CONTRIBUTING.md
├── PET_PACK_GUIDELINES.md
├── CODE_OF_CONDUCT.md
├── LICENSE                            # MIT (see §8)
├── .gitignore
└── .github/
    ├── ISSUE_TEMPLATE/
    │   ├── bug_report.md
    │   └── pet_pack_submission.md
    └── workflows/
        └── ci.yml                     # xcodebuild test on macOS runner
```

### Why each file exists (one line each)

| File | Reason |
|---|---|
| `main.swift` | Avoid storyboard; create `NSApplication`, set delegate, set `.regular` policy, `run()`. |
| `AppDelegate.swift` | The only place AppKit hands us lifecycle + dock menu + `openFiles`. Keep it thin. |
| `AppEnvironment.swift` | One place that constructs and wires objects so dependencies are explicit and testable. |
| `PetState.swift` | Shared vocabulary across animation, behavior, walk, persistence. |
| `PetController.swift` | Single brain that mediates scheduler ↔ animation ↔ walking ↔ overrides. |
| `StateTransition.swift` | Distinguishes *who* asked for a state (scheduler vs. manual vs. drop) so overrides work. |
| `AnimationController.swift` | Turns "be in state X" into a running frame loop on the Dock. |
| `SpriteSheet.swift` | Pure image-slicing; cache `NSImage`s once per profile. |
| `FrameClock.swift` | Centralize the run-loop-mode timer gotcha so every timer behaves during menu tracking. |
| `DockRenderer.swift` | Funnel *all* `applicationIconImage` writes through one main-thread actor to avoid races. |
| `BehaviorScheduler.swift` | The auto-cycling engine; independent of how frames are drawn. |
| `BehaviorConfig.swift` | Typed view of the JSON "behaviors" block. |
| `WeightedPicker.swift` | Pure, unit-testable randomness (injectable RNG). |
| `WalkWindowController.swift` | Owns overlay window config + show/hide. |
| `WalkOverlayView.swift` | Draws the dog frame; isolates Core Graphics from window plumbing. |
| `WalkPathController.swift` | Screen math (multi-display, coordinate flips) separated from rendering. |
| `PetProfile.swift` / `AnimationConfig.swift` | Codable models mirroring the JSON exactly. |
| `PetProfileLoader.swift` | Resolve + decode + validate; surfaces friendly errors. |
| `FileDropHandler.swift` | Encapsulates the food.png rule and file deletion (the only destructive op). |
| `StateStore.swift` | Thin UserDefaults wrapper; the only persistence surface. |
| `DockMenuBuilder.swift` | Build menu + map items to `PetController` actions. |

---

## 2. Class / struct architecture

> Notation: `->` = returns. Properties list *types only*. Methods list *signatures only*.
> "Depends on" lists the collaborators each type is initialized with or calls.

### `PetState.swift`
```
enum PetState: String, Codable, CaseIterable
    case idle, walk, sit, sleep, eat
```
- Responsibility: canonical state vocabulary.
- Depends on: nothing.

### `StateTransition.swift`
```
enum TransitionSource { case scheduler, manualOverride, fileDrop, restore }
struct StateTransition
    let target: PetState
    let source: TransitionSource
    let duration: TimeInterval?     // nil => driven by animation completion (e.g. eat) or external (walk)
```
- Responsibility: describe one requested move so `PetController` can apply override rules.
- Depends on: `PetState`.

### `PetProfile.swift` / `AnimationConfig.swift` / `BehaviorConfig.swift`
```
struct PetProfile: Codable
    let id: String
    let name: String
    let spriteSheet: String
    let frameSize: Int
    let animations: [String: AnimationConfig]
    let behaviors: [String: BehaviorConfig]?
    func animation(for: PetState) -> AnimationConfig?
    func behavior(for: PetState) -> BehaviorConfig?

struct AnimationConfig: Codable
    let row: Int
    let frameCount: Int
    let fps: Double

struct BehaviorConfig: Codable
    let minDuration: TimeInterval
    let maxDuration: TimeInterval
    let nextStates: [WeightedState]

struct WeightedState: Codable
    let state: PetState
    let weight: Int
```
- Responsibility: 1:1 Codable mirror of the profile JSON (animations + behaviors blocks).
- Depends on: `PetState`.

### `ProfileError.swift`
```
enum ProfileError: Error
    case fileNotFound(String)
    case spriteSheetMissing(String)
    case decodeFailed(underlying: Error)
    case validationFailed(reason: String)   // e.g. frameCount<=0, row out of sheet bounds, weights sum 0
```

### `PetProfileLoader.swift`
```
struct PetProfileLoader
    init(bundle: Bundle, fileManager: FileManager)
    func loadProfile(named: String) throws -> PetProfile
    func loadDefaultProfile() throws -> PetProfile
    func resolveSpriteSheetURL(for: PetProfile, alongside json: URL) throws -> URL
    func validate(_ profile: PetProfile, sheetPixelSize: CGSize) throws
```
- Responsibility: find JSON (bundle `Resources/Pets`, then user `pets/` dir), decode, locate PNG next to JSON, validate ranges against the actual sheet dimensions.
- Depends on: `Bundle`, `FileManager`, `PetProfile`, `ProfileError`.

### `SpriteSheet.swift`
```
final class SpriteSheet
    init(image: NSImage, frameSize: Int)
    var frameSize: Int { get }
    func frame(row: Int, index: Int) -> NSImage          // cached
    func frames(row: Int, count: Int) -> [NSImage]
    func preload(animations: [AnimationConfig])
    var pixelSize: CGSize { get }
```
- Responsibility: deterministic slicing of one PNG into cached per-frame `NSImage`s (origin/orientation handled here).
- Depends on: `NSImage`, `AnimationConfig`.

### `FrameClock.swift`
```
final class FrameClock
    init()
    var onTick: (() -> Void)?
    func start(fps: Double)
    func stop()
    var isRunning: Bool { get }
    // Internally: Timer scheduled and added to RunLoop.common modes.
```
- Responsibility: single correct timer abstraction (common run-loop modes; see §4 gotcha).
- Depends on: `Foundation.Timer`, `RunLoop`.

### `DockRenderer.swift`
```
@MainActor final class DockRenderer
    init(application: NSApplication)
    func render(_ image: NSImage)            // sets applicationIconImage
    func resetToBundleIcon()                 // applicationIconImage = nil
```
- Responsibility: the *only* writer of `NSApplication.shared.applicationIconImage`; guarantees main-thread + single-owner.
- Depends on: `NSApplication`.

### `AnimationController.swift`
```
final class AnimationController
    init(spriteSheet: SpriteSheet, profile: PetProfile, clock: FrameClock, renderer: DockRenderer)
    weak var delegate: AnimationControllerDelegate?
    private(set) var currentState: PetState
    func play(_ state: PetState, loop: Bool)
    func playOnce(_ state: PetState, completion: (() -> Void)?)   // for eat
    func stop()
    func currentFrameImage() -> NSImage?      // consumed by WalkOverlayView during walk

protocol AnimationControllerDelegate: AnyObject
    func animationDidCompleteCycle(_ state: PetState)
```
- Responsibility: own the frame index, advance per tick at the state's fps, push frames to `DockRenderer` (or expose them to the walk overlay), fire completion for one-shot states.
- Depends on: `SpriteSheet`, `PetProfile`, `FrameClock`, `DockRenderer`.

### `WeightedPicker.swift`
```
struct WeightedPicker
    static func pick<T>(_ items: [(value: T, weight: Int)], using rng: inout RandomNumberGenerator) -> T?
    static func randomDuration(min: TimeInterval, max: TimeInterval, using rng: inout RandomNumberGenerator) -> TimeInterval
```
- Responsibility: pure, injectable randomness (deterministic in tests).
- Depends on: nothing.

### `BehaviorScheduler.swift`
```
final class BehaviorScheduler
    init(profile: PetProfile, rng: RandomNumberGenerator)
    weak var delegate: BehaviorSchedulerDelegate?
    private(set) var isPaused: Bool
    private(set) var currentState: PetState
    func start(from: PetState)
    func pause()                              // manual override begins
    func resume(from: PetState)               // resume, typically from .idle
    func stop()
    // Internal: schedules a DispatchSourceTimer / Timer for the chosen duration,
    //           then asks delegate to enter the next picked state.

protocol BehaviorSchedulerDelegate: AnyObject
    func scheduler(_ s: BehaviorScheduler, wantsTransitionTo state: PetState, duration: TimeInterval)
```
- Responsibility: decide *what state comes next and for how long*. Owns ONLY scheduling logic; never touches frames, the Dock, or windows.
- Depends on: `PetProfile`/`BehaviorConfig`, `WeightedPicker`, its own timer.
- Note: separate class (see §"Scheduler design" below) — not folded into `PetController`.

### `WalkPathController.swift`
```
struct WalkStep { let origin: CGPoint; let facingLeft: Bool }
final class WalkPathController
    init(screenProvider: () -> NSScreen?)
    func makePath(speedPointsPerSec: Double, frameSize: Int) -> WalkPlan
struct WalkPlan
    let startOrigin: CGPoint
    let endOrigin: CGPoint
    let facingLeft: Bool
    func origin(atProgress: Double) -> CGPoint     // linear interpolation, bottom-left coords
```
- Responsibility: all screen-coordinate math (bottom-left origin, visibleFrame, which edge to start from, multi-display choice). No drawing, no window.
- Depends on: `NSScreen`.

### `WalkOverlayView.swift`
```
final class WalkOverlayView: NSView
    var image: NSImage?
    var flipHorizontally: Bool
    override func draw(_ dirtyRect: NSRect)
    override var isFlipped: Bool { get }   // false; AppKit default bottom-left
```
- Responsibility: draw the current walk frame, optionally mirrored for direction.
- Depends on: `NSView`, `NSImage`.

### `WalkWindowController.swift`
```
final class WalkWindowController
    init()
    var overlayView: WalkOverlayView { get }
    func show(at origin: CGPoint, size: CGSize)
    func move(to origin: CGPoint)
    func updateFrame(_ image: NSImage, flip: Bool)
    func hide()
    var isVisible: Bool { get }
    // Window configured per §5.
```
- Responsibility: create/configure/teardown the transparent overlay window; reposition it.
- Depends on: `NSWindow`, `WalkOverlayView`.

### `FileDropHandler.swift`
```
struct FileDropResult { let didEat: Bool; let deletedFile: Bool }
struct FileDropHandler
    init(fileManager: FileManager)
    func handleDrop(paths: [String]) -> FileDropResult     // food.png => delete; else keep
    func isFoodFile(_ path: String) -> Bool                // case-insensitive "food.png" basename
```
- Responsibility: the food.png rule + the single destructive deletion, isolated and testable.
- Depends on: `FileManager`.

### `StateStore.swift`
```
struct PersistedState: Codable { let lastState: PetState; let profileId: String }
struct StateStore
    init(defaults: UserDefaults)
    func save(_ state: PersistedState)
    func load() -> PersistedState?
    func clear()
```
- Responsibility: only persistence surface (UserDefaults). Note: never persist `walk`/`eat` as a resume state (see §"Persistence rules").
- Depends on: `UserDefaults`.

### `DockMenuBuilder.swift`
```
@MainActor struct DockMenuBuilder
    init(target: AnyObject, actions: DockMenuActions)
    func build() -> NSMenu        // items: Sit, Sleep, Walk, Feed (+ separator)
struct DockMenuActions
    let sit: () -> Void
    let sleep: () -> Void
    let walk: () -> Void
    let feed: () -> Void
```
- Responsibility: construct the right-click menu and bind items to closures (no business logic).
- Depends on: `NSMenu`, `PetController` (via closures).

### `PetController.swift`  (the brain)
```
@MainActor final class PetController:
        BehaviorSchedulerDelegate, AnimationControllerDelegate
    init(profile: PetProfile,
         animation: AnimationController,
         scheduler: BehaviorScheduler,
         walkWindow: WalkWindowController,
         walkPath: WalkPathController,
         renderer: DockRenderer,
         store: StateStore,
         dropHandler: FileDropHandler)
    func start()                                  // restore persisted state, begin scheduler
    func shutdown()                               // persist, stop timers, hide window

    // Manual overrides (from dock menu):
    func userRequestedSit()
    func userRequestedSleep()
    func userRequestedWalk()
    func userRequestedFeed()                      // synthetic eat (no file)

    // File drop (from AppDelegate):
    func handleDroppedFiles(_ paths: [String])

    // Delegate conformances:
    func scheduler(_:wantsTransitionTo:duration:)
    func animationDidCompleteCycle(_:)

    // Private:
    private func enter(_ transition: StateTransition)
    private func beginWalk(duration: TimeInterval, source: TransitionSource)
    private func endWalkReturnToIdle()
```
- Responsibility: the *only* object that knows the rules — apply a transition, pause/resume the scheduler on manual override, switch the Dock animation, drive walking mode, persist, and feed.
- Depends on: everything above (composition root wires it).

### `AppEnvironment.swift`
```
@MainActor final class AppEnvironment
    let petController: PetController
    init() throws    // loads default/persisted profile, builds SpriteSheet, all controllers
    func makeDockMenu() -> NSMenu
```
- Responsibility: composition root. The one place `init` graph is assembled.
- Depends on: all factories/loaders.

### `AppDelegate.swift`
```
@main? NO — use main.swift. Class is plain NSObject.
final class AppDelegate: NSObject, NSApplicationDelegate
    var environment: AppEnvironment?
    func applicationDidFinishLaunching(_:)
    func applicationWillTerminate(_:)
    func applicationDockMenu(_:) -> NSMenu?               // right-click menu hook
    func application(_:openURLs:)                         // modern file-drop hook (macOS 10.13+)
    func application(_:openFiles:)                        // legacy fallback; call replyToOpenOrPrint
    func applicationShouldHandleReopen(_:hasVisibleWindows:) -> Bool
```
- Responsibility: thin AppKit adapter → forwards to `PetController`. No logic.
- Depends on: `AppEnvironment`, `PetController`.

### `main.swift`
- Responsibility: `let app = NSApplication.shared; app.setActivationPolicy(.regular); let d = AppDelegate(); app.delegate = d; app.run()`. No storyboard.

---

## 3. Execution order (each step independently testable)

> Build vertically by capability. Every step ends with a concrete "you can verify this now."

1. **Project skeleton + launch as regular app, no window.**
   `main.swift`, `AppDelegate` (empty), Info.plist (§7), activation policy `.regular`.
   ✅ Verify: app launches, **Dock icon appears**, no window, no crash, quits cleanly.

2. **Profile models + loader + validation.** `PetState`, `PetProfile`, `AnimationConfig`,
   `BehaviorConfig`, `PetProfileLoader`, `ProfileError`. Bundle the golden_retriever JSON+PNG.
   ✅ Verify (unit): loads JSON, decodes animations+behaviors, rejects malformed/out-of-range.

3. **SpriteSheet slicing.** `SpriteSheet` with caching + `pixelSize`.
   ✅ Verify (unit): correct frame count per row; frame size == 200; out-of-bounds asserts.

4. **DockRenderer + static frame.** Push a single sliced frame to `applicationIconImage`.
   ✅ Verify: Dock icon changes to the sprite's idle frame 0.

5. **FrameClock + AnimationController looping idle.** Wire clock→controller→renderer.
   ✅ Verify: Dock icon visibly cycles the 4 idle frames at 8 fps; survives opening a menu (run-loop-mode gotcha, §4).

6. **One-shot animation (eat) with completion.** `playOnce`.
   ✅ Verify: trigger eat manually in code → plays 4 frames once → returns to idle.

7. **Dock right-click menu.** `DockMenuBuilder` + `applicationDockMenu`. Wire Sit/Sleep/Walk/Feed
   to temporary direct `AnimationController.play` calls (no scheduler yet).
   ✅ Verify: right-click Dock → 4 items → each switches the Dock animation; Feed plays eat once.

8. **WeightedPicker (pure).**
   ✅ Verify (unit): deterministic with seeded RNG; respects weights; handles zero/empty.

9. **BehaviorScheduler auto-cycling.** Delegate drives `AnimationController` via `PetController`
   (introduce a minimal `PetController` now).
   ✅ Verify: leave app alone → states change on their own per weights/durations; logs show picks.

10. **Manual override pause/resume semantics.** Menu actions call `PetController` →
    `scheduler.pause()`, run chosen animation, then `scheduler.resume(from: .idle)`.
    ✅ Verify: pick Sit from menu → scheduler stops cycling, dog sits, then auto-cycling resumes from idle.

11. **Persistence.** `StateStore`; restore on launch, save on terminate (with rules in §"Persistence").
    ✅ Verify: set a state, quit, relaunch → resumes a sane state (never mid-walk/eat).

12. **Walking mode window.** `WalkWindowController` + `WalkOverlayView` configured per §5; show a
    static walk frame at screen bottom.
    ✅ Verify: transparent borderless window appears above other apps, click-through, no shadow.

13. **Walking motion.** `WalkPathController` + tick loop moving the window across the screen while
    animating walk frames in the overlay; mirror sprite by direction.
    ✅ Verify: dog walks edge→edge along the dock line, then window hides, returns to idle in Dock.

14. **Integrate walk into scheduler + override.** Scheduler `walk` state and menu "Walk" both route
    through `PetController.beginWalk`; Dock animation pauses (or shows idle) while overlay walks.
    ✅ Verify: both scheduled and manual walks behave identically and end cleanly.

15. **File drop onto Dock.** `CFBundleDocumentTypes` in plist (§7) + `application(_:openURLs:)` →
    `FileDropHandler`. food.png → eat → delete; other → eat → keep.
    ✅ Verify: drag arbitrary file onto Dock icon → eat plays, file untouched; drag a file named
    food.png → eat plays, file is deleted. Confirm Dock highlights icon on drag-over.

16. **EAT interrupt correctness.** Ensure drop during any state pauses scheduler, plays eat once,
    resumes from idle; never schedulable.
    ✅ Verify: drop during sleep/walk → interrupts gracefully → resumes.

17. **Second pet profile (zero Swift changes) proof.** Add a second JSON+PNG; switch default by
    profile id (config/UserDefaults).
    ✅ Verify: pointing the loader at the new profile id changes the pet with no recompiled logic.

18. **Polish + hardening.** Error paths (missing profile → fallback bundle icon + log), multi-display
    walk choice, low-fps CPU check, memory (NSImage cache).
    ✅ Verify: pull the sprite PNG → app still launches with bundle icon and logs a clear error.

---

## 4. NSDockTile / `applicationIconImage` gotchas

1. **Run-loop mode kills your timer.** A default-mode `Timer` **pauses while a menu is open or a
   window is being resized/scrolled** (the run loop switches to `NSEventTrackingRunLoopMode`).
   Your Dock animation will freeze whenever the user opens the Dock menu. **Fix:** add the timer to
   `RunLoop.common` modes (this is exactly why `FrameClock` exists). Verify in step 5.

2. **Main thread only.** `applicationIconImage` must be set on the main thread. Off-main writes
   silently corrupt or no-op. `DockRenderer` is `@MainActor` for this reason.

3. **Setting it to `nil` resets to the bundle icon** — useful for `resetToBundleIcon()`, but don't
   do it accidentally between frames or you'll flicker the static icon.

4. **The Dock is a separate process; updates are async and coalesced.** Pushing frames faster than
   ~the Dock can composite drops frames. Keep fps as configured (4–12). Don't expect >~30fps.
   Rapidly setting the image in a tight loop can also spike CPU — animate at the JSON fps, not the
   timer's max.

5. **Retina sizing.** The Dock tile is 128pt but rendered on Retina. Provide images at adequate
   resolution; your 200×200 frames are fine. Let AppKit scale; don't pre-downscale to 32px.

6. **Two animation strategies — pick one and stay consistent.** (a) Set
   `NSApplication.applicationIconImage` per frame (chosen here, simplest). (b) Use
   `NSApp.dockTile.contentView = someView` then `dockTile.display()` each frame (more control,
   needed for badges/overlays). Mixing them causes one to clobber the other. MVP uses (a) only.

7. **`applicationIconImage` vs `dockTile`.** Strategy (a) does **not** automatically refresh the
   tile in all cases for *content-view* setups; since we never set a content view, simple assignment
   is enough. If a badge feature is added later, switch wholesale to `dockTile`.

8. **Custom icon is process-scoped.** On quit, the Dock reverts to the bundle icon automatically —
   no cleanup required. But during a crash the last frame may briefly persist until Dock refresh.

9. **`applicationDockMenu(_:)` is the only supported right-click hook.** Return a fresh/owned
   `NSMenu`. The system **appends** its own items (Options, Show All Windows, Quit, Force Quit on
   alt) **below** yours — you cannot remove those. Your items render at the top.

10. **Dock menu items need targets that stay alive.** If you use target/action, the target must be
    retained (use the delegate/controller, not a temporary). Closures via a retained builder avoid
    this. Validate enable/disable via `validateMenuItem(_:)` if you grey items out.

11. **Bouncing / attention.** `requestUserAttention` and dock bounce are unrelated to icon
    animation; don't trigger them for ambient behavior — annoying and out of scope.

12. **First icon set can lag at launch.** On cold launch the Dock may show the bundle icon for a
    beat before your first frame lands. Set frame 0 in `applicationDidFinishLaunching` ASAP.

13. **`NSApplication.shared.dockTile.badgeLabel`** exists but is out of MVP scope — don't set it.

14. **Image flipping/orientation.** `NSImage` drawn into the tile uses AppKit coordinate
    conventions; if frames look vertically mirrored, the slicing in `SpriteSheet` (not the Dock) is
    the culprit — fix at slice time, test in step 3.

---

## 5. Walking mode — transparent NSWindow architecture

**Window configuration (`WalkWindowController`):**

| Property | Value | Why |
|---|---|---|
| `styleMask` | `.borderless` | No title bar / chrome. |
| `backgroundColor` | `NSColor.clear` | Transparent canvas. |
| `isOpaque` | `false` | Allow alpha compositing. |
| `hasShadow` | `false` | No drop shadow around the sprite. |
| `level` | `.floating` (or `.statusBar` to sit above more) | Dog rides above normal app windows. Avoid `.screenSaver`/`.popUpMenu` unless you want it over *everything*. |
| `collectionBehavior` | `[.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]` | Visible on every Space, doesn't move with Space switches, not in Cmd-Tab/Exposé cycling, tolerated over fullscreen apps. |
| `ignoresMouseEvents` | `true` (MVP) | Click-through; non-intrusive. (Flip to false later if dog becomes interactive.) |
| `isMovableByWindowBackground` | `false` | We move it programmatically. |
| `isReleasedWhenClosed` | `false` | We reuse/hide the window. |
| `acceptsMouseMovedEvents` | `false` | Not needed for MVP. |
| size | `frameSize × frameSize` (200×200), or a tighter rect | Just big enough for one frame. |

**Content:** a single `WalkOverlayView` as `contentView`. Each tick: set `overlayView.image` to the
current walk frame from `AnimationController.currentFrameImage()`, set `flipHorizontally` by
direction, `needsDisplay = true`.

**Coordinate system (critical):**
- AppKit screen coordinates are **bottom-left origin**, Y grows upward. (UIKit/CG top-left
  intuition is wrong here.)
- Use `NSScreen` to get bounds. `screen.frame` includes the menu bar + Dock area;
  `screen.visibleFrame` excludes them. For "walk along the floor *above* the Dock," anchor the
  window's `origin.y` near `visibleFrame.minY` (so the dog stands on the Dock line, not behind it).
- Horizontal walk: interpolate `origin.x` from `frame.maxX - frameSize` (right edge) to
  `frame.minX` (left edge) — or reverse. `facingLeft` is derived from travel direction; mirror the
  sprite accordingly.
- **Multi-display:** `NSScreen.screens` is an array; `NSScreen.main` is the one with the key window
  (may be nil for an agent-ish app). `WalkPathController` takes a `screenProvider` closure so the
  display choice (main / mouse screen / largest) is testable and swappable. Coordinates are in a
  global space where each screen has an offset origin — don't assume (0,0) is your screen.
- Movement: `WalkPathController.makePath` produces a `WalkPlan`; the tick loop computes
  `origin(atProgress:)` from elapsed/duration and calls `window.setFrameOrigin`. Keep motion timer
  in `RunLoop.common` modes too.

**Lifecycle / interaction with the rest of the system:**
- `PetController.beginWalk(duration:source:)`: pause Dock idle animation (or hold it on a static
  frame), `walkWindow.show(...)`, start the position+frame loop. On completion (duration elapsed or
  reaching the edge) → `walkWindow.hide()` → `endWalkReturnToIdle()` → if walk was scheduler-driven,
  `scheduler` proceeds; if manual, `scheduler.resume(from: .idle)`.
- During walk, the Dock can either freeze on idle frame 0 or keep idling — pick freeze for clarity.
- Window is created lazily and reused (hidden, not destroyed) to avoid per-walk allocation fl_icker.

---

## 6. Drag-and-drop onto the Dock icon

Non-sandboxed direct-download app, so you have full file access — no security-scoped bookmarks
needed. The mechanism is **document opening**, not `NSDraggingDestination` (that's for in-window
drops). The Dock routes a file dropped on the icon as an "open documents" request.

**Required pieces:**
1. **Declare acceptable document types in Info.plist** (`CFBundleDocumentTypes`) — *without this the
   Dock will not highlight the icon on drag-over and will refuse the drop.* Declare a broad type so
   "any file" works (see §7).
2. **Implement the open hooks in `AppDelegate`:**
   - Preferred (modern): `application(_ sender: NSApplication, open urls: [URL])` /
     `application(_:openURLs:)` — gives file URLs for dropped files.
   - Legacy fallback: `application(_ sender: NSApplication, openFiles filenames: [String])` — if you
     implement this, call `sender.replyToOpenOrPrint(.success)` when done.
   - Single-file legacy: `application(_:openFile:)` — optional; the array variants cover it.
   Implement the modern `openURLs` and keep `openFiles` as a safety net; don't implement both doing
   the same work twice — route both into one `PetController.handleDroppedFiles([String])`.
3. **`applicationShouldHandleReopen(_:hasVisibleWindows:)`** → return `false` (we have no windows to
   reopen; prevents odd behavior when the icon is clicked).

**Flow:** Dock drop → `openURLs` → `PetController.handleDroppedFiles(paths)` →
`FileDropHandler.handleDrop` → it computes `isFoodFile` (case-insensitive basename == `food.png`);
if food → trigger eat → delete file via `FileManager.removeItem`; else → trigger eat → leave file.
The eat trigger is an **interrupt**: pause scheduler, `animation.playOnce(.eat)`, on completion
resume from idle.

**Gotchas:**
- Drops while the app is *not* running will *launch* it and then deliver via the same hooks — make
  sure `applicationDidFinishLaunching` finishes wiring before `openURLs` fires (it can arrive
  immediately after launch). Guard `handleDroppedFiles` until `environment` is ready (queue if nil).
- The Dock only accepts the drop if the dragged item's UTI matches a declared `LSItemContentTypes`.
  Use `public.item` (the root of files+folders) to accept truly anything.
- Folders: if a folder is dropped, decide policy (MVP: treat as "other", just eat). `FileDropHandler`
  checks `isDirectory` to avoid trying to delete folders even if oddly named.
- Deletion is the only destructive action in the app — keep it isolated, log it, unit-test the
  food-vs-not branching with a temp directory.

---

## 7. Info.plist keys

> **Reminder from §0: do NOT set `LSUIElement`.** It would remove the Dock icon entirely.

| Key | Value | Purpose |
|---|---|---|
| `CFBundleName` | `LittlePup` | App name. |
| `CFBundleDisplayName` | `LittlePup` | Display name. |
| `CFBundleIdentifier` | `com.littlepup.app` (or your reverse-DNS) | Bundle id. |
| `CFBundleVersion` / `CFBundleShortVersionString` | e.g. `1` / `0.1.0` | Build/marketing versions. |
| `CFBundlePackageType` | `APPL` | App package. |
| `NSPrincipalClass` | `NSApplication` | App class. |
| `NSHighResolutionCapable` | `true` | Retina rendering for crisp Dock frames. |
| `LSMinimumSystemVersion` | e.g. `12.0` | Min macOS. |
| `NSHumanReadableCopyright` | "© 2026 …" | Legal. |
| `LSApplicationCategoryType` | `public.app-category.entertainment` | Category. |
| **`CFBundleDocumentTypes`** | array → one dict (below) | **Required for Dock file-drop acceptance.** |
| `NSSupportsAutomaticTermination` | `false` | Don't let macOS quietly kill the ambient pet. |
| `NSSupportsSuddenTermination` | `false` | Ensure `applicationWillTerminate` (persistence) runs. |

**`CFBundleDocumentTypes` entry (accept any file):**
```
CFBundleTypeName        = "Any File"
CFBundleTypeRole        = "Viewer"
LSHandlerRank           = "None"          # we don't want to become default opener for everything
LSItemContentTypes      = ["public.item"] # root UTI: matches any file or folder
```
- `LSHandlerRank = None` is important: it lets you *accept drops* without registering LittlePup as a
  candidate default app for every file type in Finder's "Open With."

**Explicitly NOT set / why:**
- `LSUIElement` — would hide the Dock icon (fatal). Omit.
- `NSMainStoryboardFile` / `NSMainNibFile` — omit; we launch programmatically with no window.
- App Sandbox entitlements — not sandboxed; full file access for deletion. (If you ever ship via a
  channel requiring sandbox, food.png deletion needs security-scoped access — out of scope.)

**"Launches without a window"** is not a plist key — it's a consequence of having no storyboard and
not calling `makeKeyAndOrderFront`. **"No menu-bar icon"** = simply never create an `NSStatusItem`.

---

## 8. Open-source repository considerations

**License — recommendation: MIT** for the app code.
- Permissive, contributor-friendly, compatible with later commercial/premium pet packs.
- Rationale vs. alternatives: GPL would force derivative/premium-pack tooling to stay open; Apache-2.0
  is also fine (adds explicit patent grant) — choose Apache-2.0 if you want patent protection, else
  MIT for simplicity. Avoid copyleft if you plan a premium-pack business.
- **Dual-licensing strategy for premium packs:** keep the *engine* MIT, but license *art assets*
  (sprite PNGs) separately. Put free community packs under CC BY 4.0 (or CC BY-SA) and reserve
  premium packs under a proprietary asset license. Code license ≠ asset license — state this clearly.

**Top-level repo files:**

- `README.md` — what it is, screenshot/GIF, install (download .app / build from source), how to add a
  pet pack, feature list, roadmap, license summary (code vs. assets), credits.
- `CONTRIBUTING.md` — dev setup (Xcode version, macOS min), build/test commands
  (`xcodebuild test`), code style, branch/PR conventions, DCO/CLA note, how to run locally, how the
  architecture is organized (link this doc).
- `PET_PACK_GUIDELINES.md` — the headline community feature. Must contain:
  - Sprite-sheet spec: 200×200 frames, transparent PNG, fixed row order
    (0 idle / 1 walk / 2 sit / 3 sleep / 4 eat), frame counts per row.
  - JSON schema with **all** fields including the `behaviors` block; a full annotated example.
  - Validation rules (row in range, frameCount ≤ sheet width/frameSize, fps > 0, weights ≥ 0 with
    nonzero sum, durations min ≤ max).
  - Naming conventions (`<id>.json` + `<id>_sprites.png` side by side; lowercase snake_case id).
  - Where to drop packs locally (`~/Library/Application Support/LittlePup/pets/` or repo `pets/`),
    and submission process (PR to `pets/` with both files + a preview GIF).
  - Asset licensing requirement for contributed packs (must be CC BY 4.0 or compatible; declare
    original authorship).
- `CODE_OF_CONDUCT.md` — Contributor Covenant.
- `docs/PET_PACK_FORMAT.md` — machine-focused JSON schema (could ship a JSON Schema file for
  validation/CI).
- `docs/ARCHITECTURE.md` — this document.
- `.github/ISSUE_TEMPLATE/pet_pack_submission.md` — structured pack submissions.
- `.github/workflows/ci.yml` — `xcodebuild test` on a macOS runner + a JSON-schema lint of all packs
  in `pets/` so bad packs are rejected automatically.
- `.gitignore` — `build/`, `DerivedData/`, `.DS_Store`, `*.xcuserstate`, `xcuserdata/`.

**Premium-pack-ready structure now (no code cost):**
- Loader already reads packs from a user directory (`Application Support/LittlePup/pets/`) *and* the
  bundle. Premium packs are just additional pack folders dropped there — no engine change.
- Keep a stable, versioned pack format (`"formatVersion"` could be added to JSON later; note it in
  guidelines as reserved) so premium packs remain forward-compatible.
- Keep engine and assets in separate license files from day one to avoid relicensing pain later.

---

## Cross-cutting design decisions (explicit answers to the brief)

### Scheduler design — separate class, not part of PetController
`BehaviorScheduler` is its own class. Rationale:
- Single responsibility: it only decides *next state + duration*; it must be unit-testable with a
  seeded RNG and a fake clock, with zero AppKit.
- `PetController` is the AppKit-aware mediator (animation, window, Dock, persistence). Folding the
  scheduler in would make timing logic untestable without UI.
- Interaction: `BehaviorScheduler` → (delegate) → `PetController.scheduler(_:wantsTransitionTo:duration:)`
  → `PetController` enacts it via `AnimationController`/`WalkWindowController`.

### Scheduler ↔ AnimationController
They never talk directly. `PetController` translates a scheduler decision into an animation command.
This keeps "what state next" (scheduler) decoupled from "draw frames" (animation).

### Manual override pause/resume
1. Menu action → `PetController.userRequestedX()`.
2. `scheduler.pause()` (cancels its pending timer).
3. `PetController` runs the chosen animation (loop for sit/sleep, one-shot for feed/eat, walk for
   walk).
4. On completion → `scheduler.resume(from: .idle)` so cycling restarts from idle (per brief).

### Walk needs screen/window coords, not just animation state
Handled by splitting concerns: `BehaviorScheduler` only emits `walk` + a duration. `PetController`
calls `beginWalk`, which uses `WalkPathController` (screen math) + `WalkWindowController` (overlay).
The scheduler stays coordinate-agnostic; walking specifics live in `Walking/`.

### EAT is interrupt-only
Never appears in any `nextStates`. Only entered via `handleDroppedFiles` (file drop) or `Feed` menu
(synthetic). Always: pause scheduler → `playOnce(.eat)` → resume from idle. Not persisted as a
resume state.

### Persistence rules (StateStore)
- Persist on `applicationWillTerminate` and on each settled state change.
- **Never persist `eat`** (transient interrupt) and **never restore into `walk`** mid-motion. On
  restore, map `walk`/`eat` → `idle`. Persist `idle/sit/sleep` as-is.
- Also persist `profileId` so the chosen pet survives relaunch.
- On restore, enter the saved state via a `restore`-sourced `StateTransition`, then start the
  scheduler.

### Threading
All AppKit-touching types (`DockRenderer`, `PetController`, window/menu) are `@MainActor`.
`BehaviorScheduler`/`WeightedPicker`/loaders are plain and tested off the UI. Timers fire on the main
run loop in `.common` modes.
```
```

> Build order is strictly §3. Do not start a step before the previous step's ✅ check passes.
