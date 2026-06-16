# LittlePup

A tiny golden retriever that lives in your macOS Dock — rent free.

---

## Download

Go to the [Releases](https://github.com/devyangggg/LittlePup/releases) page and download **LittlePup.pkg** from the latest release.

---

## Install

1. Download **LittlePup.pkg** and double-click it
2. Click through the installer — it puts the app in your Applications folder automatically
3. Open LittlePup from Applications or Spotlight

**First launch only** — macOS will block it because the app isn't signed with a paid Apple certificate. To get past this:

**Option A (easiest):** Right-click `LittlePup.pkg` → click **Open** → click **Open** in the popup, then run through the installer

**Option B (Terminal):** Run this once after installing, then open normally:
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
