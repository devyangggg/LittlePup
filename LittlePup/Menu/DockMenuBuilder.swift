// DockMenuBuilder.swift – constructs the right-click Dock NSMenu from closure actions

import AppKit // NSMenu and NSMenuItem live in AppKit

// Closures for each menu command; AppDelegate fills these in Step 7,
// PetController replaces them with scheduler-aware versions in Step 9
struct DockMenuActions {
    // Return to the idle blink-and-hold loop
    let idle: () -> Void
    // Loop the sit animation until another action interrupts
    let sit: () -> Void
    // Loop the sleep animation until another action interrupts
    let sleep: () -> Void
    // Loop the walk animation until another action interrupts (overlay added in Step 12)
    let walk: () -> Void
    // Play eat once, then return to idle
    let feed: () -> Void
    // Play bark once, then return to idle
    let bark: () -> Void
}

// Builds the right-click Dock menu from DockMenuActions closures.
// Must be retained for the lifetime of the Dock menu — NSMenuItem.target holds self strongly,
// and self holds the closures; releasing this object before the menu is discarded would crash.
@MainActor final class DockMenuBuilder: NSObject {

    // Pet identity shown as a non-clickable header at the top of every menu
    private let petName: String
    private let petDescription: String?
    // The action closures passed at init time; replaced by PetController in Step 9
    private let actions: DockMenuActions

    init(petName: String, petDescription: String?, actions: DockMenuActions) {
        self.petName = petName
        self.petDescription = petDescription
        self.actions = actions
    }

    // Construct and return a fresh NSMenu; applicationDockMenu(_:) calls this each right-click
    func build() -> NSMenu {
        // Allocate a new NSMenu; AppKit discards the previous one automatically
        let menu = NSMenu()
        // Pet name header — disabled so it acts as a label, not a button
        menu.addItem(headerItem(petName))
        // Personality description on the line below the name if present
        if let desc = petDescription { menu.addItem(headerItem(desc)) }
        menu.addItem(.separator())
        // Looping state actions
        menu.addItem(makeItem(title: "Idle",  closure: actions.idle))
        menu.addItem(makeItem(title: "Sit",   closure: actions.sit))
        menu.addItem(makeItem(title: "Sleep", closure: actions.sleep))
        menu.addItem(makeItem(title: "Walk",  closure: actions.walk))
        // Visual separator before the one-shot actions
        menu.addItem(.separator())
        menu.addItem(makeItem(title: "Feed",  closure: actions.feed))
        menu.addItem(makeItem(title: "Bark",  closure: actions.bark))
        return menu
    }

    // Build a non-clickable label item used for the pet name and description header
    private func headerItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    // Build a single NSMenuItem wired to the given closure
    private func makeItem(title: String, closure: @escaping () -> Void) -> NSMenuItem {
        // action must be an @objc selector; menuItemFired(_:) dispatches to the boxed closure
        let item = NSMenuItem(title: title,
                              action: #selector(menuItemFired(_:)),
                              keyEquivalent: "")
        // target must outlive the menu; self is retained by AppDelegate → safe
        item.target = self
        // representedObject is strongly retained by NSMenuItem → ClosureBox stays alive
        item.representedObject = ClosureBox(closure)
        return item
    }

    // Single dispatch point for all menu items; extracts and calls the boxed closure
    @objc private func menuItemFired(_ sender: NSMenuItem) {
        // Cast representedObject back to ClosureBox and invoke the stored closure
        (sender.representedObject as? ClosureBox)?.call()
    }
}

// Wraps a Swift closure so it can be stored in NSMenuItem.representedObject (which is Any?)
// without losing the closure type information
private final class ClosureBox: NSObject {
    // The Swift closure to execute when the menu item is selected
    let call: () -> Void
    // Store the closure at init time; it captures whatever context the caller needs
    init(_ call: @escaping () -> Void) { self.call = call }
}
