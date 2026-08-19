import AppKit
import SwiftUI

@MainActor
final class MainWindowController: NSWindowController, NSWindowDelegate {
    static let shared = MainWindowController()

    func hide() {
        window?.orderOut(nil)
    }

    /// Oran degistiginde cagrilir. En kucuk icerik boyutu yeniden hesaplanir
    /// ve pencere bunun altinda kaldiysa buyutulur; kullanicinin elle
    /// ayarladigi daha genis boyut korunur.
    func applyScale() {
        guard let window else { return }
        let minimum = UIScale.minimumContentSize(for: UIScale.current)
        window.contentMinSize = minimum
        let current = window.contentRect(forFrameRect: window.frame).size
        let target = NSSize(width: max(current.width, minimum.width),
                            height: max(current.height, minimum.height))
        guard target != current else { return }
        window.setContentSize(target)
    }

    func show(store: ClockStore, exchangeRates: ExchangeRateStore) {
        if window == nil {
            let minimum = UIScale.minimumContentSize(for: UIScale.current)
            let window = NSWindow(
                contentRect: NSRect(origin: .zero, size: minimum),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "Clockin"
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.backgroundColor = NSColor(red: 0.055, green: 0.065, blue: 0.08, alpha: 1)
            // En kucuk boyut orana gore belirlenir; ustunde serbest buyur.
            window.contentMinSize = minimum
            window.setFrameAutosaveName("ClockinMainWindow")
            window.delegate = self
            window.contentView = NSHostingView(rootView:
                MainView()
                    .environmentObject(store)
                    .environmentObject(exchangeRates)
            )
            // Elle ayarlanan boyutu geri getir, ama oranin gerektirdigi en
            // kucuk boyutun altina dusmesine izin verme.
            window.setFrameUsingName("ClockinMainWindow")
            let restored = window.contentRect(forFrameRect: window.frame).size
            if restored.width < minimum.width || restored.height < minimum.height {
                window.setContentSize(NSSize(width: max(restored.width, minimum.width),
                                             height: max(restored.height, minimum.height)))
            }

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
