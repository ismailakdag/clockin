import AppKit
import SwiftUI

@MainActor
final class MainWindowController: NSWindowController, NSWindowDelegate {
    static let shared = MainWindowController()

    func hide() {
        window?.orderOut(nil)
    }

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
            window.contentView = NSHostingView(rootView:
                MainView()
                    .environmentObject(store)
                    .environmentObject(exchangeRates)
            )
            // Always start a fresh launch on the primary display. A previous
            // autosaved frame can belong to a disconnected/virtual display.
            let screen = NSScreen.screens.first ?? NSScreen.main
            let frame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
            let size = window.frame.size
            window.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2))
            self.window = window
        }

        // Accessory/menu-bar apps do not always activate a normal window when
        // launched from Finder or `open`. Temporarily use a regular activation
        // policy while presenting it, then force the window to the front.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
        // Keep the presentation deterministic after launch.
        DispatchQueue.main.async { [weak self] in
            self?.window?.orderFrontRegardless()
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}
