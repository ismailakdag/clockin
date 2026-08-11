import AppKit
import SwiftUI

@MainActor
final class MainWindowController: NSWindowController, NSWindowDelegate {
    static let shared = MainWindowController()

    func show(store: ClockStore, exchangeRates: ExchangeRateStore) {
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 390, height: 650),
                styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "Clockin"
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.backgroundColor = NSColor(red: 0.055, green: 0.065, blue: 0.08, alpha: 1)
            window.contentMinSize = NSSize(width: 390, height: 650)
            window.contentMaxSize = NSSize(width: 390, height: 650)
            window.delegate = self
            window.setFrameAutosaveName("ClockinMainWindow")
            window.contentView = NSHostingView(rootView:
                MainView()
                    .environmentObject(store)
                    .environmentObject(exchangeRates)
            )
            if !window.setFrameUsingName("ClockinMainWindow") { window.center() }
            self.window = window
        }

        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}
