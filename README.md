# LittlePup

A tiny golden retriever that lives in your macOS Dock — rent free.

---

## Download

Go to the [Releases](https://github.com/devyangggg/LittlePup/releases) page and download **LittlePup.zip** from the latest release.

---

## Install

1. Unzip **LittlePup.zip**
2. Drag **LittlePup.app** into your **Applications** folder
3. Double-click to launch

**First launch only** — macOS will block it with "developer cannot be verified" because the app isn't signed with a paid Apple certificate. To get past this:

**Option A (easiest):** Right-click `LittlePup.app` → click **Open** → click **Open** in the popup

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
