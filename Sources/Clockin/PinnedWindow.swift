import AppKit
import SwiftUI

@MainActor
final class PinnedWindowController: NSObject, NSWindowDelegate {
    static let shared = PinnedWindowController()
    private var panel: NSPanel?

    func update(isVisible: Bool, store: ClockStore) {
        if isVisible {
            if panel == nil { panel = makePanel(store: store) }
            panel?.orderFrontRegardless()
        } else {
            panel?.orderOut(nil)
        }
    }

    func applyPreset(_ mode: String) {
        guard let panel else { return }
        let size = savedSize(for: mode) ?? defaultSize(for: mode)
        var frame = panel.frame
        frame.origin.y += frame.height - size.height
        frame.size = size
        panel.setFrame(frame, display: true, animate: true)
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        saveCurrentSize()
    }

    func windowDidMove(_ notification: Notification) {
        panel?.saveFrame(usingName: "ClockinPinnedTimer")
    }

    private func defaultSize(for mode: String) -> NSSize {
        switch mode {
        case "Compact": return NSSize(width: 246, height: 72)
        case "Goal": return NSSize(width: 300, height: 116)
        case "All": return NSSize(width: 370, height: 230)
        default: return NSSize(width: 320, height: 112)
        }
    }

    private func savedSize(for mode: String) -> NSSize? {
        let defaults = UserDefaults.standard
        let widthKey = "Clockin.PinnedWidth.\(mode)"
        let heightKey = "Clockin.PinnedHeight.\(mode)"
        guard defaults.object(forKey: widthKey) != nil, defaults.object(forKey: heightKey) != nil else { return nil }
        let width = defaults.double(forKey: widthKey)
        let height = defaults.double(forKey: heightKey)
        guard width > 0, height > 0 else { return nil }
        return NSSize(width: width, height: height)
    }

    private func saveCurrentSize() {
        guard let panel else { return }
        let mode = UserDefaults.standard.string(forKey: "Clockin.PinnedMode") ?? "Money"
        UserDefaults.standard.set(panel.frame.width, forKey: "Clockin.PinnedWidth.\(mode)")
        UserDefaults.standard.set(panel.frame.height, forKey: "Clockin.PinnedHeight.\(mode)")
        panel.saveFrame(usingName: "ClockinPinnedTimer")
    }

    private func makePanel(store: ClockStore) -> NSPanel {
        let savedMode = UserDefaults.standard.string(forKey: "Clockin.PinnedMode") ?? "Money"
        let initialSize = savedMode == "Compact" ? NSSize(width: 246, height: 72) : (savedMode == "Goal" ? NSSize(width: 300, height: 116) : (savedMode == "All" ? NSSize(width: 370, height: 190) : NSSize(width: 320, height: 112)))
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.minSize = NSSize(width: 246, height: 72)
        panel.maxSize = NSSize(width: 640, height: 500)
        panel.setFrameAutosaveName("ClockinPinnedTimer")
        panel.delegate = self
        panel.contentView = NSHostingView(rootView:
            PinnedTimerView()
                .environmentObject(store)
                .environmentObject(AppDependencies.shared.exchangeRates)
                .environmentObject(RadioController.shared)
        )

        let restored = panel.setFrameUsingName("ClockinPinnedTimer")
        if let saved = savedSize(for: savedMode) {
            var frame = panel.frame
            frame.origin.y += frame.height - saved.height
            frame.size = saved
            panel.setFrame(frame, display: false)
        } else if !restored, let screen = NSScreen.main {
            let visible = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: visible.maxX - 266, y: visible.maxY - 92))
        }
        return panel
    }
}

struct PinnedTimerView: View {
    @EnvironmentObject private var store: ClockStore
    @EnvironmentObject private var exchangeRates: ExchangeRateStore
    @EnvironmentObject private var radio: RadioController
    @AppStorage("Clockin.PinnedMode") private var mode = "Money"
    @AppStorage("Clockin.Theme") private var themeRaw = ClockinThemeChoice.carbon.rawValue
    @AppStorage("Clockin.GoalDailyHours") private var dailyGoalHours = 0.0
    @AppStorage("Clockin.GoalMonthlyHours") private var monthlyGoalHours = 0.0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var now = Date()
    private var theme: ClockinPalette { ClockinThemeChoice.selected(themeRaw).palette }

    var body: some View {
        Group {
            if mode == "Compact" { compactContent } else if mode == "Goal" { goalContent } else if mode == "All" { allContent } else { moneyContent }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.12)))
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 7)).foregroundStyle(.white.opacity(0.2)).padding(6)
        }
        .preferredColorScheme(theme.colorScheme)
        .fontDesign(theme.fontDesign)
        .onReceive(timer) { now = $0 }
    }

    private var compactContent: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(store.running == nil ? Color.secondary : (store.running?.isPaused == true ? .orange : theme.accent))
                .frame(width: 8, height: 8)
                .shadow(color: store.running?.isPaused == false ? theme.accent.opacity(0.8) : .clear, radius: 5)

            VStack(alignment: .leading, spacing: 2) {
                Text(store.running == nil ? "READY" : (store.running?.isPaused == true ? "PAUSED" : "CLOCKED IN"))
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .tracking(1.2)
                Text(DurationText.clock(store.elapsed(at: now)))
                    .font(.system(size: 23, weight: .medium, design: .monospaced))
                    .contentTransition(.numericText())
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(store.currentEarnings(at: now).money(code: store.currencyCode))
                    .font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(theme.accent)
                if store.currencyCode == "USD", let rate = exchangeRates.latestRate {
                    Text((store.currentEarnings(at: now) * rate).money(code: "TRY"))
                        .font(.system(size: 9, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private var moneyContent: some View {
        let usd = store.currentEarnings(at: now)
        let rate = exchangeRates.latestRate
        let isEarning = store.running?.isPaused == false
        let perSecond = isEarning ? store.hourlyRate / 3600 : 0
        return VStack(spacing: 8) {
            HStack {
                HStack(spacing: 7) {
                    Circle().fill(isEarning ? theme.accent : (store.running == nil ? .secondary : .orange))
                        .frame(width: 7, height: 7).shadow(color: isEarning ? theme.accent : .clear, radius: 4)
                    Text(store.running == nil ? "READY" : (isEarning ? "MONEY IS MOVING" : "PAUSED"))
                        .font(.system(size: 8, weight: .black, design: .rounded)).foregroundStyle(.secondary).tracking(1)
                }
                Spacer()
                Text(DurationText.clock(store.elapsed(at: now)))
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
            }
            HStack(alignment: .firstTextBaseline) {
                Text(usd.money(code: store.currencyCode))
                    .font(.system(size: 21, weight: .bold, design: .rounded)).foregroundStyle(theme.accent)
                Spacer()
                if store.currencyCode == "USD", let rate {
                    Text("≈ \((usd * rate).money(code: "TRY"))")
                        .font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                }
            }
            HStack {
                Text("+\(perSecond.money(code: store.currencyCode, maxFractionDigits: 4)) every second")
                Spacer()
                if store.currencyCode == "USD", let rate {
                    Text("+\((perSecond * rate).money(code: "TRY", maxFractionDigits: 4))/sec")
                }
            }
            .font(.system(size: 8, weight: .semibold, design: .monospaced))
            .foregroundStyle(isEarning ? theme.accent : .secondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
    }

    private var goalContent: some View {
        let day = store.todayDuration(at: now) / 3600
        let month = store.monthDuration(at: now) / 3600
        return VStack(alignment: .leading, spacing: 9) {
            HStack { Image(systemName: "target").foregroundStyle(theme.accent); Text("GOAL MODE").font(.system(size: 9, weight: .black)).tracking(1); Spacer(); Text(DurationText.clock(store.elapsed(at: now))).font(.system(size: 14, design: .monospaced)) }
            goalGauge("TODAY", value: day, goal: dailyGoalHours)
            goalGauge("MONTH", value: month, goal: monthlyGoalHours)
        }
        .padding(14)
    }

    private var allContent: some View {
        let earning = store.currentEarnings(at: now)
        let rate = exchangeRates.latestRate
        let active = store.running?.isPaused == false
        let perSecond = active ? store.hourlyRate / 3600 : 0
        let day = store.todayDuration(at: now) / 3600
        let month = store.monthDuration(at: now) / 3600
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(active ? theme.accent : (store.running == nil ? .secondary : .orange)).frame(width: 7, height: 7)
                    Text(store.running == nil ? "READY" : (active ? "MONEY IS MOVING" : "PAUSED"))
                        .font(.system(size: 8, weight: .black)).foregroundStyle(.secondary).tracking(1)
                }
                Spacer()
                Text(DurationText.clock(store.elapsed(at: now))).font(.system(size: 16, design: .monospaced))
            }
            HStack(alignment: .firstTextBaseline) {
                Text(earning.money(code: store.currencyCode)).font(.system(size: 23, weight: .bold, design: .rounded)).foregroundStyle(theme.accent)
                Spacer()
                if store.currencyCode == "USD", let rate { Text("≈ \((earning * rate).money(code: "TRY"))").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white) }
            }
            HStack {
                Label("+\(perSecond.money(code: store.currencyCode, maxFractionDigits: 4))/sec", systemImage: "bolt.fill")
                Spacer()
                Text("Today \(hoursText(day))").foregroundStyle(theme.secondary)
            }
            .font(.system(size: 8, weight: .semibold, design: .monospaced))
            HStack(spacing: 6) {
                let averages = allTimeAverages(at: now)
                averageChip("DAY", hours: averages.day)
                averageChip("WEEK", hours: averages.week)
                averageChip("MONTH", hours: averages.month)
            }
            if dailyGoalHours > 0 { goalGauge("DAY", value: day, goal: dailyGoalHours) }
            if monthlyGoalHours > 0 { goalGauge("MONTH", value: month, goal: monthlyGoalHours) }
            HStack(spacing: 7) {
                Image(systemName: radio.isPlaying ? "music.note.list" : "music.note").foregroundStyle(radio.isPlaying ? theme.accent : .secondary)
                Text(radio.isPlaying ? "FOCUS RADIO ON" : "FOCUS RADIO OFF").font(.system(size: 8, weight: .bold, design: .monospaced))
                Spacer()
                Button { if radio.isPlaying { radio.stop() } else { radio.play(station: radio.stations[0]) } } label: { Image(systemName: radio.isPlaying ? "stop.fill" : "play.fill") }.buttonStyle(.plain)
                Slider(value: $radio.volume, in: 0...1).frame(width: 65).tint(theme.accent)
            }
        }
        .padding(15)
    }

    private func goalGauge(_ label: String, value: Double, goal: Double) -> some View {
        let progress = goal > 0 ? min(max(value / goal, 0), 1) : 0
        return VStack(alignment: .leading, spacing: 3) {
            HStack { Text(label).font(.system(size: 8, weight: .bold)).foregroundStyle(.secondary); Spacer(); Text(goal > 0 ? "\(hoursText(value)) / \(hoursText(goal))" : "Set in Settings").font(.system(size: 9, weight: .semibold, design: .monospaced)) }
            ProgressView(value: progress).tint(progress >= 1 ? .green : theme.accent).scaleEffect(y: 0.8)
            if goal > 0 { Text(progress >= 1 ? "GOAL REACHED" : "\(hoursText(max(0, goal - value))) remaining").font(.system(size: 8, weight: .bold)).foregroundStyle(progress >= 1 ? .green : theme.accent) }
        }
    }

    private func hoursText(_ hours: Double) -> String { let m = max(0, Int((hours * 60).rounded())); return "\(m / 60)h \(m % 60)m" }

    private func averageChip(_ label: String, hours: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("AVG \(label)").font(.system(size: 7, weight: .bold)).foregroundStyle(.secondary)
            Text(hoursText(hours)).font(.system(size: 8, weight: .semibold, design: .monospaced))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4).padding(.horizontal, 6)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
    }

    private func allTimeAverages(at date: Date) -> (day: Double, week: Double, month: Double) {
        let calendar = Calendar.autoupdatingCurrent
        let earliest = store.sessions.map(\.start).min() ?? store.running?.start ?? date
        let start = calendar.startOfDay(for: earliest)
        let end = calendar.startOfDay(for: date)
        let calendarDays = max(1, (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1)
        let daily = store.allDuration(at: date) / 3600 / Double(calendarDays)
        return (daily, daily * 7, daily * 30.44)
    }

}
