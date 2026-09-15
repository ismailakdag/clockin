// Opens the real menu-bar panel host in a throwaway accessory process and checks
// what matters for full-screen use: the panel never activates Clockin, joins
// every Space, sits under the menu-bar item, follows its content's height from
// the top edge and closes on Esc, a second click and an outside click.
//
// swiftc -swift-version 6 Sources/Clockin/Models.swift Sources/Clockin/MenuBarStatus.swift Sources/Clockin/MenuBarIcon.swift Sources/Clockin/MenuBarController.swift Tests/manual/menubarpanelhost/main.swift -o /tmp/clockin-menubarpanelhost-tests && /tmp/clockin-menubarpanelhost-tests
//
// It briefly adds a Clockin icon to the menu bar and removes it on exit.
import AppKit
import Combine
import SwiftUI

var passed = 0
@MainActor func check(_ condition: Bool, _ message: String) {
    guard condition else {
        FileHandle.standardError.write(Data("FAILED: \(message)\n".utf8))
        exit(1)
    }
    passed += 1
    print("ok: \(message)")
}

/// Whether macOS made this process the active app. `NSApp.isActive` turns
/// true while a non-activating panel is key, but the system's frontmost app,
/// which decides Space switches, stays the app the user was in.
func systemActivated() -> Bool {
    NSRunningApplication.current.isActive
        || NSWorkspace.shared.frontmostApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier
}

func spin(_ seconds: TimeInterval) {
    RunLoop.main.run(until: Date(timeIntervalSinceNow: seconds))
}

// Pure positioning.
let screen = NSRect(x: 0, y: 0, width: 1512, height: 982)
let visible = NSRect(x: 0, y: 0, width: 1512, height: 950)
let size = NSSize(width: 320, height: 300)
let centred = MenuBarController.panelOrigin(size: size, below: NSRect(x: 900, y: 950, width: 40, height: 32), screenFrame: screen, visibleFrame: visible)
check(centred == NSPoint(x: 760, y: 645), "the panel is centred under the item with a small gap")
let rightEdge = MenuBarController.panelOrigin(size: size, below: NSRect(x: 1480, y: 950, width: 30, height: 32), screenFrame: screen, visibleFrame: visible)
check(rightEdge.x == 1512 - 8 - 320, "an item at the right edge keeps the panel on screen")
let fullScreen = MenuBarController.panelOrigin(size: size, below: NSRect(x: 900, y: 950, width: 40, height: 32), screenFrame: screen, visibleFrame: screen)
check(fullScreen.y == 645, "in a full-screen Space the item, not the visible frame, sets the top")
let secondScreen = NSRect(x: 1512, y: 0, width: 1920, height: 1080)
let onSecond = MenuBarController.panelOrigin(size: size, below: NSRect(x: 1600, y: 1055, width: 40, height: 25), screenFrame: secondScreen, visibleFrame: secondScreen)
check(onSecond.x == 1512 + 8 && onSecond.y == 1055 - 5 - 300, "on a second display the panel stays on that display")
let hidden = MenuBarController.panelOrigin(size: size, below: nil, screenFrame: screen, visibleFrame: visible)
check(hidden.x == 1512 - 8 - 320 && hidden.y == 950 - 5 - 300, "without an item frame the panel falls back to the top right")

// The live host.
@MainActor final class Model: ObservableObject {
    @Published var tall = false
    @Published var running = false
}
let model = Model()

struct Content: View {
    @ObservedObject var model: Model
    let close: @MainActor () -> Void
    var body: some View {
        VStack(spacing: 0) {
            Text("Panel").frame(height: 120)
            if model.tall { Color.gray.frame(height: 140) }
        }
        .frame(width: 320)
        .background(Color.white)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
app.finishLaunching()
check(!systemActivated(), "the harness starts inactive, like Clockin behind a full-screen app")

let controller = MenuBarController.shared
var minimal = true
let changes = PassthroughSubject<Void, Never>()
controller.start(MenuBarController.Host(
    status: {
        model.running
            ? MenuBarStatus(state: .running, text: "01:07 · $28")
            : MenuBarStatus(state: .idle, text: nil)
    },
    minimalMode: { minimal },
    changes: changes.eraseToAnyPublisher(),
    content: { close in AnyView(Content(model: model, close: close)) },
    menu: { NSMenu() }
))
spin(0.3)

guard let button = controller.statusItem?.button else { check(false, "the status item has a button"); exit(1) }
check(button.image?.isTemplate == true, "the menu-bar icon is a template image")
check(button.title.isEmpty, "idle in minimal mode the item is the icon alone")
model.running = true
changes.send()
spin(0.2)
check(button.title == " 01:07 · $28", "clocked in, the session text follows the icon")
minimal = false
changes.send()
spin(0.2)
check(button.title == " Clockin", "outside minimal mode the item keeps its name")

spin(0.5)
controller.open()
spin(0.4)
guard let panel = controller.panel else { check(false, "opening creates the panel"); exit(1) }
check(panel.isVisible && panel.alphaValue == 1, "the panel is shown")
check(!systemActivated(), "opening the panel does not activate Clockin, so no Space switch")
check(panel.isKeyWindow, "the panel is key without activation, so Esc reaches it")
check(panel.styleMask.contains(.nonactivatingPanel), "the panel is non-activating")
check(panel.collectionBehavior.contains(.canJoinAllSpaces) && panel.collectionBehavior.contains(.fullScreenAuxiliary),
      "the panel joins every Space, including full-screen ones")
check(panel.level.rawValue >= NSWindow.Level.popUpMenu.rawValue, "the panel sits above full-screen windows and the pinned timer")
check(panel.frame.width == 320 && abs(panel.frame.height - 120) <= 1, "the panel takes its content's size")
if let buttonWindow = button.window {
    let itemFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
    check(abs(panel.frame.maxY - (itemFrame.minY - 5)) <= 1, "the panel hangs just below the menu-bar item")
    check(abs(panel.frame.midX - itemFrame.midX) <= 1 || panel.frame.maxX <= (buttonWindow.screen?.frame.maxX ?? .infinity) - 7,
          "the panel is centred under the item or held on screen")
}
let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
check(windows.contains { ($0[kCGWindowNumber as String] as? Int) == panel.windowNumber }, "the window server has the panel on screen")

let top = panel.frame.maxY
model.tall = true
spin(0.4)
check(abs(panel.frame.height - 260) <= 1 && abs(panel.frame.maxY - top) <= 0.5, "taller content grows the panel downward, top edge fixed")
model.tall = false
spin(0.4)
check(abs(panel.frame.height - 120) <= 1 && abs(panel.frame.maxY - top) <= 0.5, "shorter content shrinks it back")

panel.cancelOperation(nil)
spin(0.4)
check(!panel.isVisible, "Esc closes the panel")

button.performClick(nil)
spin(0.4)
check(controller.isOpen, "clicking the item opens the panel")
check(!systemActivated(), "still not activated after a click on the item")
button.performClick(nil)
spin(0.4)
check(!panel.isVisible, "clicking the item again closes it")

// A click in another Clockin window closes the panel.
let other = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 200, height: 120), styleMask: [.titled], backing: .buffered, defer: false)
other.orderFrontRegardless()
controller.open()
spin(0.4)
check(controller.isOpen, "reopened")
if let click = NSEvent.mouseEvent(with: .leftMouseDown, location: NSPoint(x: 50, y: 50), modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                                  windowNumber: other.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1) {
    app.postEvent(click, atStart: false)
    // Local monitors run as the app dequeues an event; other queued events
    // (window server housekeeping) may come first.
    let deadline = Date(timeIntervalSinceNow: 1)
    while let event = app.nextEvent(matching: .any, until: deadline, inMode: .default, dequeue: true) {
        app.sendEvent(event)
        if event.type == .leftMouseDown { break }
    }
}
spin(0.4)
check(!panel.isVisible, "a click in another window closes the panel")

controller.open()
spin(0.3)
NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
spin(0.2)
check(!panel.isVisible, "switching Spaces closes the panel instead of leaving it behind")

// Reopening during a close animation must not be hidden by the old animation.
controller.open()
spin(0.3)
controller.close()
controller.open()
spin(0.5)
check(panel.isVisible && panel.alphaValue == 1, "reopening mid-close keeps the panel visible")
check(!systemActivated(), "Clockin never became active")

print("\(passed) menu bar panel host checks passed")
