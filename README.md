# LittlePup

A tiny golden retriever that lives in your macOS Dock (or your Windows taskbar) — rent free.

> **macOS** users: see below. **Windows** users: jump to [LittlePup for Windows](#littlepup-for-windows).

---

## Download

Go to the [Releases](https://github.com/devyangggg/LittlePup/releases) page and download **LittlePup.dmg** from the latest release.

---

## Install

1. Open **LittlePup.dmg**
2. **Drag `LittlePup.app` onto the Applications folder** shown in the window
3. Open LittlePup from Applications or Spotlight

**First launch only** — macOS will block it because the app isn't signed with a paid Apple certificate. To get past this, do **one** of the following:

**Option A (easiest):** In Applications, right-click `LittlePup` → click **Open** → click **Open** in the popup. macOS remembers this and opens it normally from then on.

**Option B (Terminal):** Run this once, then open normally:
```bash
xattr -dr com.apple.quarantine /Applications/LittlePup.app
```

After that it opens like any other app, every time.

---

## What it does

LittlePup puts an animated golden retriever in your Dock tile. No windows, no menus, no setup — just a dog hanging out next to your other apps.

The animation runs automatically, cycling through idle blinking, sitting, sleeping, walking, and running based on weighted random transitions.

---

## Dock menu

Right-click the LittlePup icon in your Dock to control the pet manually:

| Item | What it does |
|------|-------------|
| **Idle** | Returns to the default blinking loop |
| **Sit** | Pet sits and blinks in place |
| **Sleep** | Pet breathes slowly, pauses, breathes again |
| **Walk** | Pet walks in place |
| **Feed** | Plays the eating animation once, then goes back to idle |
| **Bark** | Plays the bark animation once, then goes back to idle |
| **Check for Updates…** | Checks GitHub for a newer release; if one exists, offers to download it |

## Feeding by drag and drop

Drag a file named **`food.png`** onto the LittlePup icon in the Dock and the pet plays the eating animation automatically. Any other file is ignored.

---

## Quit

Right-click the Dock icon → **Quit**.

---

## Requirements

- macOS 12 Monterey or later
- Works on both Apple Silicon and Intel Macs

---

## Build from source

```bash
# Requires Xcode and xcodegen
brew install xcodegen

git clone https://github.com/devyangggg/LittlePup.git
cd LittlePup
xcodegen generate
open LittlePup.xcodeproj
```

Press **Run** in Xcode (or `Cmd+R`).

---

# LittlePup for Windows

Windows has no Dock, so on Windows the pet lives on your **taskbar** (the bar with the Start
button and your running apps). The taskbar button's icon *is* the dog — it animates there, and
right-clicking it opens the menu via the taskbar **Jump List**.

## Download & run

Download the latest single executable — no installer, no .NET required, nothing to unzip:

**[⬇ Download LittlePup.exe](https://github.com/devyangggg/LittlePup/releases/download/win-latest/LittlePup.exe)**

Double-click `LittlePup.exe` and the pet appears on your taskbar.

**First run only:** Windows SmartScreen may warn that the app is from an unknown publisher (it
isn't signed with a paid certificate). Click **More info → Run anyway**. It opens normally after that.

## Right-click (Jump List) menu

Right-click the LittlePup icon on the taskbar:

| Item | What it does |
|------|-------------|
| **Idle** | Returns to the default blinking loop |
| **Sit** | Pet sits and blinks in place |
| **Sleep** | Pet breathes slowly, pauses, breathes again |
| **Walk** | Pet walks in place |
| **Feed** | Plays the eating animation once, then goes back to idle |
| **Bark** | Plays the bark animation once, then goes back to idle |
| **Check for Updates** | Checks GitHub for a newer build; if one exists, offers to download it |
| **Quit** | Exits LittlePup |

> **Note:** Windows can't accept files dropped onto a taskbar button, so the macOS `food.png`
> drag-and-drop feeding is replaced by the **Feed** menu item on Windows.

## Requirements (Windows)

- Windows 10 or 11 (x64)
- No .NET install needed — the exe is fully self-contained

## Build from source (Windows)

```powershell
# Requires the .NET 8 SDK
git clone https://github.com/devyangggg/LittlePup.git
cd LittlePup\windows
dotnet build LittlePup.Windows.sln -c Release

# Or produce the self-contained single-file exe:
dotnet publish LittlePup\LittlePup.csproj -c Release -r win-x64 --self-contained true `
  -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -o publish
```

Both platforms read the **same** pet definition (`LittlePup/Resources/Pets/golden_retriever.json`
+ sprite sheet), so the dog looks and behaves identically.
