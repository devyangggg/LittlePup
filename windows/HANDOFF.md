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

## What still needs real testing on Windows (couldn't be done on the Mac)
1. **Build locally:** `cd windows && dotnet build LittlePup.Windows.sln -c Release` (needs .NET 8 SDK).
2. **Run it:** launch `LittlePup.exe` → a taskbar button with the golden-retriever icon should
   appear and **animate** (idle blink loop). No visible window. ← *human eyeball needed.*
3. **Jump List menu:** right-click the taskbar icon → Idle/Sit/Sleep/Walk/Feed/Bark/Check for
   Updates/Quit. Each should change state; Quit exits. ← *human eyeball needed.*
4. **Single-instance forwarding:** with it running, `LittlePup.exe --action=sit` should change the
   running pet (NOT open a second taskbar button).
5. **Watch for:** taskbar icon throttling/flicker (Windows may rate-limit icon redraws), Jump List
   actually showing our items, no GDI handle leak over time.

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
