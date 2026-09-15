import AppKit
import SwiftUI

/// Things only the AppKit host can do. The host closes the panel before opening windows.
struct MenuBarPanelActions {
    var openApp: @MainActor () -> Void
    var close: @MainActor () -> Void
    var checkForUpdates: @MainActor () -> Void
    var quit: @MainActor () -> Void
}

struct MenuBarPanelView: View {
    let actions: MenuBarPanelActions
    /// ImageRenderer cannot reproduce window backdrop materials. Production keeps this false.
    var previewSolidBackground = false

    @EnvironmentObject private var store: ClockStore
    @EnvironmentObject private var exchangeRates: ExchangeRateStore
    @EnvironmentObject private var radio: RadioController
    @EnvironmentObject private var updates: UpdateChecker
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("Clockin.Theme") private var themeRaw = ClockinThemeChoice.carbon.rawValue
    @AppStorage("Clockin.MascotEnabled") private var mascotEnabled = true
    @AppStorage("Clockin.GoalDailyHours") private var dailyGoalHours = 0.0
    @AppStorage("Clockin.MinimalMode") private var minimalMode = false
    @State private var now = Date()
    @State private var confirmingDiscard = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private var theme: ClockinPalette { ClockinThemeChoice.selected(themeRaw).palette }
    private var paused: Bool { store.running?.isPaused == true }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if store.running != nil { earnings }
            today
            primaryActions
            if radio.isPlaying {
                Button { change { radio.stop() } } label: {
                    Label("Stop focus radio", systemImage: "stop.circle")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(PanelTextStyle())
                .accessibilityLabel("Stop focus radio")
            }
            Divider()
            footer
        }
        .font(.system(size: 12))
        .padding(14)
        .frame(width: 320)
        .fixedSize(horizontal: false, vertical: true)
        .background {
            let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
            if previewSolidBackground { shape.fill(theme.background) }
            else { shape.fill(.regularMaterial) }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(theme.surfaceStroke, lineWidth: 0.5)
                .allowsHitTesting(false)
        }
        .preferredColorScheme(theme.colorScheme)
        .fontDesign(theme.fontDesign)
        .tint(theme.accent)
        .onReceive(timer) { if store.running != nil { now = $0 } }
        .onChange(of: store.running == nil) { _, _ in
            now = Date()
            confirmingDiscard = false
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            if mascotEnabled {
                ClockinMascotStage().environmentObject(store)
                    .frame(width: 44, height: 44)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle().fill(store.running == nil ? Color.secondary : (paused ? .orange : theme.accent))
                        .frame(width: 6, height: 6).accessibilityHidden(true)
                    Text(store.running == nil ? "Not clocked in" : (paused ? "Paused" : "Clocked in"))
                        .foregroundStyle(store.running == nil ? .primary : .secondary)
                        .font(store.running == nil ? .system(size: 17, weight: .semibold) : nil)
                }
                if store.running != nil {
                    Text(DurationText.clock(store.elapsed(at: now)))
                        .font(.system(size: 30, weight: .medium)).monospacedDigit()
                        .contentTransition(.numericText())
                        .accessibilityLabel("Session time, \(DurationText.clock(store.elapsed(at: now)))")
                }
                // Idle, today's total is in the strip below; repeating it here
                // read as a stopped timer.
            }
            Spacer(minLength: 0)
        }
    }

    private var earnings: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(store.currentEarnings(at: now).money(code: store.currencyCode))
                .font(.system(size: 20, weight: .semibold)).foregroundStyle(theme.accent)
                .accessibilityLabel("Session earnings, \(store.currentEarnings(at: now).money(code: store.currencyCode))")
            Spacer(minLength: 0)
            if store.currencyCode == "USD", let rate = exchangeRates.latestRate {
                Text((store.currentEarnings(at: now) * rate).money(code: "TRY"))
                    .foregroundStyle(.secondary)
            }
        }
        .monospacedDigit().lineLimit(1).minimumScaleFactor(0.75)
    }

    private var today: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Today").foregroundStyle(.secondary)
                Text(DurationText.compact(store.todayDuration(at: now)))
                Spacer(minLength: 4)
                Text(store.todayEarnings(at: now).money(code: store.currencyCode))
            }
            .monospacedDigit().lineLimit(1).minimumScaleFactor(0.8)
            if dailyGoalHours > 0 {
                let duration = store.todayDuration(at: now)
                let goal = dailyGoalHours * 3600
                ProgressView(value: min(1, max(0, duration / goal)))
                    .progressViewStyle(PanelGoalStyle(accent: theme.accent))
                    .accessibilityLabel("Daily goal")
                    .accessibilityValue("\(DurationText.compact(duration)) of \(DurationText.compact(goal))")
                Text(duration >= goal ? "Daily goal reached" : "\(DurationText.compact(max(0, goal - duration))) to daily goal")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 9))
    }

    private var primaryActions: some View {
        VStack(spacing: 10) {
            if store.running == nil {
                Button("Clock in") { change { store.clockIn() } }
                    .buttonStyle(PanelActionStyle(theme: theme, primary: true))
                    .accessibilityLabel("Clock in")
            } else {
                HStack(spacing: 10) {
                    Button(paused ? "Resume" : "Pause") {
                        change { if paused { store.resume() } else { store.pause() } }
                    }
                    .buttonStyle(PanelActionStyle(theme: theme, primary: false))
                    .accessibilityLabel(paused ? "Resume session" : "Pause session")
                    Button("Clock out") { change { _ = store.clockOut() } }
                        .buttonStyle(PanelActionStyle(theme: theme, primary: true))
                        .accessibilityLabel("Clock out and save session")
                }
                if confirmingDiscard {
                    HStack(spacing: 10) {
                        Text("Discard this session?").foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                        Button("Discard", role: .destructive) { change { store.cancelRunning() } }
                            .accessibilityLabel("Discard current session without saving")
                        Button("Keep") { change { confirmingDiscard = false } }
                            .accessibilityLabel("Keep current session")
                    }
                    .buttonStyle(PanelTextStyle())
                } else {
                    Button("Cancel session") { change { confirmingDiscard = true } }
                        .buttonStyle(PanelTextStyle()).foregroundStyle(.secondary)
                        .accessibilityLabel("Cancel session, asks for confirmation")
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button("Open Clockin", action: actions.openApp)
                .accessibilityLabel("Open Clockin main window")
            if !minimalMode {
                Button(store.pinVisible ? "Unpin timer" : "Pin timer") { store.setPinned(!store.pinVisible) }
                    .accessibilityLabel(store.pinVisible ? "Unpin timer" : "Pin timer")
            }
            Spacer(minLength: 0)
            if previewSolidBackground {
                Image(systemName: "ellipsis").frame(width: 24, height: 20)
                    .accessibilityLabel("More Clockin options")
            } else {
            Menu {
                Toggle("Minimal menu bar mode", isOn: Binding(
                    get: { minimalMode },
                    set: { value in change { Self.setMinimalMode(value, store: store) } }
                ))
                Button("Check for Updates…", action: actions.checkForUpdates)
                    .disabled(!updates.canCheckForUpdates)
                Divider()
                Button("Quit Clockin", action: actions.quit)
            } label: {
                Image(systemName: "ellipsis").frame(width: 24, height: 20)
            }
            .menuIndicator(.hidden).menuStyle(.borderlessButton).fixedSize()
            .accessibilityLabel("More Clockin options").help("More Clockin options")
            }
        }
        .font(.system(size: 11)).foregroundStyle(.secondary).buttonStyle(PanelTextStyle())
    }

    private func change(_ operation: () -> Void) {
        if reduceMotion { operation(); now = Date() }
        else { withAnimation(.spring(duration: 0.25, bounce: 0.12)) { operation(); now = Date() } }
    }

    @MainActor
    static func setMinimalMode(_ on: Bool, store: ClockStore) {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "Clockin.MinimalMode") != on else { return }
        defaults.set(on, forKey: "Clockin.MinimalMode")
        if on {
            defaults.set(store.pinVisible, forKey: "Clockin.PinVisibleBeforeMinimal")
            NSApp.setActivationPolicy(.accessory)
            store.setPinned(false)
            MainWindowController.shared.hide()
        } else {
            let restore = defaults.object(forKey: "Clockin.PinVisibleBeforeMinimal") as? Bool ?? true
            defaults.removeObject(forKey: "Clockin.PinVisibleBeforeMinimal")
            MainWindowController.shared.show(store: store, exchangeRates: AppDependencies.shared.exchangeRates)
            store.setPinned(restore)
        }
    }
}

private struct PanelActionStyle: ButtonStyle {
    let theme: ClockinPalette
    let primary: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .frame(maxWidth: .infinity).padding(.vertical, 11)
            .foregroundStyle(primary ? theme.actionForeground : (theme.colorScheme == .light ? Color.black : .white))
            .background(primary ? theme.accent : theme.surface, in: RoundedRectangle(cornerRadius: 9))
            .opacity(configuration.isPressed ? 0.75 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 9))
    }
}

private struct PanelTextStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 3)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

private struct PanelGoalStyle: ProgressViewStyle {
    let accent: Color

    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { geometry in
            Capsule().fill(accent.opacity(0.16))
                .overlay(alignment: .leading) {
                    Capsule().fill(accent)
                        .frame(width: geometry.size.width * (configuration.fractionCompleted ?? 0))
                }
        }
        .frame(height: 4)
    }
}
