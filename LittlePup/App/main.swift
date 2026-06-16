// main.swift – programmatic entry point; intentionally replaces the storyboard/nib launch path

import AppKit // NSApplication and all AppKit types live here

// Obtain the singleton application object (creates it if it does not already exist)
let app = NSApplication.shared

// Set activation policy to .regular so a Dock icon appears (NOT .accessory / LSUIElement)
app.setActivationPolicy(.regular)

// main.swift runs on the main thread; assumeIsolated asserts this to the Swift concurrency system
// so that the @MainActor-isolated AppDelegate class can be constructed here without async/await
let delegate: AppDelegate = MainActor.assumeIsolated { AppDelegate() }

// Attach the delegate; must happen before app.run() so applicationDidFinishLaunching fires
app.delegate = delegate

// Enter the main run loop; this call blocks until the app is told to quit
app.run()
