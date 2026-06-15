// main.swift – programmatic entry point; intentionally replaces the storyboard/nib launch path

import AppKit // NSApplication and all AppKit types live here

// Obtain the singleton application object (creates it if it does not already exist)
let app = NSApplication.shared

// Set activation policy to .regular so a Dock icon appears (NOT .accessory / LSUIElement)
app.setActivationPolicy(.regular)

// Instantiate the delegate before assigning it so the app can call lifecycle methods
let delegate = AppDelegate()

// Attach the delegate; must happen before app.run() so applicationDidFinishLaunching fires
app.delegate = delegate

// Enter the main run loop; this call blocks until the app is told to quit
app.run()
