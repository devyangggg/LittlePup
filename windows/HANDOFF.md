# LittlePup Windows — session handoff

> Paste this to a fresh Claude Code session on the Windows machine:
> *"Read windows/HANDOFF.md and continue — we're testing the Windows build."*

## Where we are
- The macOS app (Swift/AppKit, Dock pet) is the original, untouched.
- A **native Windows port** was added under `windows/` (WPF, .NET 8). The pet lives on the
  **taskbar**: a hidden window's taskbar-button icon is animated frame-by-frame (`WM_SETICON`),
  and the right-click menu is a taskbar **Jump List** whose commands are forwarded to the single
  running instance over a named pipe.
- It **compiles and ships via CI** (`.github/workflows/windows.yml`) as a single self-contained
  `LittlePup.exe`, published to a rolling `win-latest` **pre-release** (kept out of `releases/latest`
  so the macOS DMG link/updater are unaffected).
- Latest CI build succeeded; current Windows version: see the `win-latest` release name.

## Test results (2026-06-17, Windows 11, self-contained publish build)
Verified on a real Windows box. **All programmatically-checkable items pass; visual items still need a human eyeball.**

- ✅ **Builds clean:** `dotnet build … -c Release` and the self-contained single-file `dotnet publish`
  both succeed with **0 warnings / 0 errors** (.NET SDK 8.0.422, installed per-user via dot.net script).
- ✅ **Launches & stays alive:** taskbar window (HWND) is created and the process survives idle.
- ✅ **Single-instance forwarding:** with the pet running, `LittlePup.exe --action=<cmd>` forwards over
  the named pipe and the forwarder **exits cleanly (code 0)** — instance count stays at **1**, no second
  taskbar button. Exercised idle/sit/sleep/walk/feed/bark in a row; pet stayed single & alive.
- ✅ **Quit:** `--action=quit` exits all instances cleanly.
- ✅ **No GDI/handle leak:** handle count stayed flat (~683→~692, oscillating, no upward trend) across
  many icon swaps + actions. `IconRenderer.SetIcon` correctly `DestroyIcon`s the prior frame's HICONs.
- ✅ **Action wiring matches:** JumpListBuilder emits idle/sit/sleep/walk/feed/bark/update/quit and
  `PetController.HandleAction` routes exactly those.

### ⚠️ Environment gotcha discovered
A framework-dependent (`dotnet build`) LittlePup.exe needs the **WPF Desktop runtime** installed
machine-wide. A partial `winget install Microsoft.DotNet.SDK.8` (cancelled at the UAC prompt under
`--disable-interactivity`, exit 1602) left only the **base** .NET runtime, so the build-output exe
crashed *intermittently* with "You must install or update .NET to run this application." **The shipping
artifact is the self-contained single-file publish, which has no external runtime dependency and is
unaffected** — always test/ship that one, not `bin\…\LittlePup.exe`.

## Still needs a human eyeball (can't be verified headless)
2. **Run it:** launch `publish\LittlePup.exe` → a taskbar button with the golden-retriever icon should
   appear and **animate** (idle blink loop). No visible window. ← *human eyeball needed.* (one is running now.)
3. **Jump List menu:** right-click the taskbar icon → Idle/Sit/Sleep/Walk/Feed/Bark/Check for
   Updates/Quit. Each should visibly change state. ← *human eyeball needed.*
5. **Watch for:** taskbar icon throttling/flicker (Windows may rate-limit icon redraws), the Jump List
   actually showing our 8 items, and the `update` ("Check for Updates") network path.

## Key commands
```powershell
git clone https://github.com/devyangggg/LittlePup.git
cd LittlePup\windows
dotnet build LittlePup.Windows.sln -c Release
# self-contained single-file exe:
dotnet publish LittlePup\LittlePup.csproj -c Release -r win-x64 --self-contained true `
  -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -o publish
# or grab the CI-built exe directly:
# https://github.com/devyangggg/LittlePup/releases/download/win-latest/LittlePup.exe
```

## Architecture map (windows/LittlePup/)
- `App.xaml.cs` — entry; single-instance guard; routes `--action=` to the running app; installs Jump List.
- `PetWindow.xaml.cs` — hidden minimized taskbar window; wires the animation stack on SourceInitialized.
- `Animation/IconRenderer.cs` — frame → HICON → `WM_SETICON` (the "Dock").
- `Animation/{SpriteSheet,AnimationController,FrameClock}.cs` — ports of the Swift logic.
- `Behavior/BehaviorScheduler.cs` — personality-weighted idle/sleep/run auto-cycle.
- `Core/{PetState,PetController}.cs`, `Profile/*` (embedded JSON+PNG), `Menu/JumpListBuilder.cs`,
  `Ipc/SingleInstance.cs`, `Update/UpdateChecker.cs`.
- Pet assets are the SAME files as macOS: `LittlePup/Resources/Pets/golden_retriever.json` + sprite.

## Working preferences to carry over
- **Never `git push` without explicit consent** — commit locally, then ask each time.
- Full design rationale: the macOS `ARCHITECTURE.md` (repo root) and the plan that produced this
  port (was at `~/.claude/plans/starry-noodling-beaver.md` on the Mac — not in the repo).
