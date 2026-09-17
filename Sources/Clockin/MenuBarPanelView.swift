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
    @AppStorage(UIScale.key) private var uiScale = UIScale.defaultPercent
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
        VStack(alignment: .leading, spacing: S(12)) {
            if let version = updates.pendingVersion { updateReminder(version) }
            header
            earnings
            today
            primaryActions
            if radio.isPlaying {
                Button { change { radio.stop() } } label: {
                    Label("Stop focus radio", systemImage: "stop.circle")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.clockin(.secondary, size: .small))
                .accessibilityLabel("Stop focus radio")
            }
            Divider()
            footer
        }
        .font(.system(size: S(12)))
        .padding(S(14))
        .frame(width: S(320))
        .fixedSize(horizontal: false, vertical: true)
        .background {
            let shape = RoundedRectangle(cornerRadius: S(14), style: .continuous)
            if previewSolidBackground { shape.fill(theme.background) }
            else { shape.fill(.regularMaterial) }
        }
        .overlay {
            RoundedRectangle(cornerRadius: S(14), style: .continuous)
                .strokeBorder(theme.surfaceStroke, lineWidth: 0.5)
                .allowsHitTesting(false)
        }
        .preferredColorScheme(theme.colorScheme)
        .fontDesign(theme.fontDesign)
        .clockinTextStyles()
        .tint(theme.accent)
        .onReceive(timer) { if store.running != nil { now = $0 } }
        .onChange(of: store.running == nil) { _, _ in
            now = Date()
            confirmingDiscard = false
        }
    }

    /// The line under Clock in, in place of a running session's controls.
    private var lastSessionSummary: String {
        guard let last = store.sessions.max(by: { $0.start < $1.start }) else { return "No sessions yet" }
        let when = last.start.formatted(.dateTime.month(.abbreviated).day().hour().minute())
        return "Last session \(DurationText.compact(last.duration)) · \(when)"
    }

    /// A background check found an update and left it for the user to open.
    private func updateReminder(_ version: String) -> some View {
        Button(action: actions.checkForUpdates) {
            HStack(spacing: S(8)) {
                Image(systemName: "arrow.down.circle.fill").foregroundStyle(theme.accent)
                Text("Clockin \(version) is available")
                Spacer(minLength: S(0))
                Text("Install").fontWeight(.semibold).foregroundStyle(theme.accent)
            }
            .padding(.horizontal, S(10)).padding(.vertical, S(8))
            .background(theme.surface, in: RoundedRectangle(cornerRadius: S(9)))
        }
        .buttonStyle(.clockin(.secondary, size: .small))
        .accessibilityLabel("Install Clockin \(version)")
    }

    private var header: some View {
        HStack(spacing: S(12)) {
            if mascotEnabled {
                Group {
                    // ImageRenderer cannot draw the layer-backed mascot.
                    if previewSolidBackground {
                        ClockinMascotStill(mood: store.running == nil ? .hello : (paused ? .coffee : .working))
                    } else {
                        ClockinMascotStage().environmentObject(store)
                    }
                }
                    .frame(width: S(44), height: S(44))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: S(4)) {
                HStack(spacing: S(6)) {
                    Circle().fill(store.running == nil ? Color.secondary : (paused ? .orange : theme.accent))
                        .frame(width: S(6), height: S(6)).accessibilityHidden(true)
                    Text(store.running == nil ? "Not clocked in" : (paused ? "Paused" : "Clocked in"))
                        .foregroundStyle(.secondary)
                }
                // The same slot in every state, so clocking in or out never
                // changes the panel's height: the session timer while it runs,
                // today's worked time while it does not.
                HStack(alignment: .firstTextBaseline, spacing: S(6)) {
                    if store.running == nil && store.todayDuration(at: now) <= 0 {
                        // Nothing worked yet: a row of zeros says less than this.
                        Text("Ready").font(.system(size: S(30), weight: .medium))
                    } else {
                        let shown = store.running == nil ? store.todayDuration(at: now) : store.elapsed(at: now)
                        RollingText(DurationText.clock(shown), value: shown, size: S(30), weight: .medium,
                                    design: theme.fontDesign)
                        if store.running == nil {
                            Text("today").font(.system(size: S(11))).foregroundStyle(.secondary)
                        }
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(store.running == nil
                                    ? "Worked today, \(DurationText.clock(store.todayDuration(at: now)))"
                                    : "Session time, \(DurationText.clock(store.elapsed(at: now)))")
            }
            Spacer(minLength: S(0))
        }
    }

    /// Earnings for the running session, or today's total when idle.
    private var earnings: some View {
        let running = store.running != nil
        let amount = running ? store.currentEarnings(at: now) : store.todayEarnings(at: now)
        let idleWithoutWork = !running && store.todayDuration(at: now) <= 0
        return HStack(alignment: .firstTextBaseline, spacing: S(8)) {
            if idleWithoutWork {
                Text(store.currentRate(at: now).money(code: store.currencyCode))
                    .font(.system(size: S(20), weight: .semibold)).foregroundStyle(theme.accent)
                Text("an hour").foregroundStyle(.secondary)
                Spacer(minLength: S(0))
            } else {
            RollingText(amount.money(code: store.currencyCode), value: amount, size: S(20), weight: .semibold,
                        design: theme.fontDesign, color: theme.accent)
                .accessibilityLabel(running ? "Session earnings, \(amount.money(code: store.currencyCode))"
                                            : "Earned today, \(amount.money(code: store.currencyCode))")
            Spacer(minLength: S(0))
            if store.currencyCode == "USD", let rate = exchangeRates.latestRate {
                RollingText((amount * rate).money(code: "TRY"), value: amount * rate, size: S(12),
                            design: theme.fontDesign, color: theme.secondaryText)
            }
            }
        }
        .monospacedDigit().lineLimit(1).minimumScaleFactor(0.75)
    }

    private var today: some View {
        VStack(alignment: .leading, spacing: S(8)) {
            HStack {
                Text("This month").foregroundStyle(.secondary)
                Text(DurationText.compact(store.monthDuration(at: now)))
                Spacer(minLength: S(4))
                RollingText(store.monthEarnings(at: now).money(code: store.currencyCode),
                            value: store.monthEarnings(at: now), size: S(12), design: theme.fontDesign)
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
                    .font(.system(size: S(11))).foregroundStyle(.secondary)
            }
        }
        .padding(S(10))
        .background(theme.surface, in: RoundedRectangle(cornerRadius: S(9)))
    }

    private var primaryActions: some View {
        VStack(spacing: S(10)) {
            if store.running == nil {
                Button("Clock in") { change { store.clockIn() } }
                    .buttonStyle(.clockin(.primary, size: .large, fullWidth: true))
                    .accessibilityLabel("Clock in")
                // Keeps the same rows as a running session, so the panel does
                // not resize under the pointer when you clock in or out.
                Text(lastSessionSummary)
                    .font(.system(size: S(11))).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: S(26))
                    .lineLimit(1)
            } else {
                HStack(spacing: S(10)) {
                    Button(paused ? "Resume" : "Pause") {
                        change { if paused { store.resume() } else { store.pause() } }
                    }
                    .buttonStyle(.clockin(.secondary, size: .large, fullWidth: true))
                    .accessibilityLabel(paused ? "Resume session" : "Pause session")
                    Button("Clock out") { change { _ = store.clockOut() } }
                        .buttonStyle(.clockin(.primary, size: .large, fullWidth: true))
                        .accessibilityLabel("Clock out and save session")
                }
                if confirmingDiscard {
                    HStack(spacing: S(10)) {
                        Text("Discard this session?").foregroundStyle(.secondary)
                        Spacer(minLength: S(0))
                        Button("Discard", role: .destructive) { change { store.cancelRunning() } }
                            .buttonStyle(.clockin(.destructive, size: .small))
                            .accessibilityLabel("Discard current session without saving")
                        Button("Keep") { change { confirmingDiscard = false } }
                            .accessibilityLabel("Keep current session")
                    }
                    .buttonStyle(.clockin(.secondary, size: .small))
                } else {
                    Button("Cancel session") { change { confirmingDiscard = true } }
                        .buttonStyle(.clockin(.secondary, size: .small)).foregroundStyle(.secondary)
                        .accessibilityLabel("Cancel session, asks for confirmation")
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: S(6)) {
            Button("Open Clockin", action: actions.openApp)
                .accessibilityLabel("Open Clockin main window")
            if !minimalMode {
                Button(store.pinVisible ? "Unpin timer" : "Pin timer") { store.setPinned(!store.pinVisible) }
                    .accessibilityLabel(store.pinVisible ? "Unpin timer" : "Pin timer")
            }
            Spacer(minLength: S(0))
            if previewSolidBackground {
                Image(systemName: "ellipsis").frame(width: S(24), height: S(20))
                    .accessibilityLabel("More Clockin options")
            } else {
            Menu {
                Toggle("Minimal menu bar mode", isOn: Binding(
                    get: { minimalMode },
                    set: { value in change { Self.setMinimalMode(value, store: store) } }
                ))
                Button("Check for Updates…", action: actions.checkForUpdates)
                    .disabled(!updates.isReady)
                Divider()
                Button("Quit Clockin", action: actions.quit)
            } label: {
                Image(systemName: "ellipsis").frame(width: S(24), height: S(20))
            }
            .menuIndicator(.hidden).menuStyle(.button).buttonStyle(.clockinIcon(size: 28)).fixedSize()
            .accessibilityLabel("More Clockin options").help("More Clockin options")
            }
        }
        .font(.system(size: S(11))).foregroundStyle(.secondary).buttonStyle(.clockin(.secondary, size: .small))
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
        .frame(height: S(4))
    }
}
