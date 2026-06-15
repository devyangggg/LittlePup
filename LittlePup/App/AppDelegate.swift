// AppDelegate.swift – thin AppKit adapter; receives OS lifecycle events and will forward to AppEnvironment

import AppKit // NSApplicationDelegate protocol is part of AppKit

// Must be NSObject so the Objective-C runtime can call delegate methods via selectors
final class AppDelegate: NSObject, NSApplicationDelegate {

    // Called once, after the app's run loop starts but before any UI is displayed
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Step 1: nothing to set up yet; AppEnvironment construction is added in later steps
    }

    // Called just before the process exits; used for persistence in Step 11
    func applicationWillTerminate(_ notification: Notification) {
        // Step 11: will call environment.petController.shutdown() here
    }

    // Returning false prevents macOS from trying to reopen a window when the Dock icon is clicked
    func applicationShouldHandleReopen(_ sender: NSApplication,
                                       hasVisibleWindows flag: Bool) -> Bool {
        // We intentionally have no windows; ignore the reopen request
        return false
    }

    // Provides the right-click Dock menu; wired to DockMenuBuilder in Step 7
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        // Step 7: will return DockMenuBuilder().build() here
        return nil
    }

    // Modern file-drop hook (macOS 10.13+); called when files are dropped onto the Dock icon
    func application(_ application: NSApplication, open urls: [URL]) {
        // Step 15: will route through FileDropHandler via PetController
    }

    // Legacy file-drop hook; acts as a safety net for older launch-service paths
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        // Step 15: will delegate to the modern path then call replyToOpenOrPrint
        sender.reply(toOpenOrPrint: .success)
    }
}
