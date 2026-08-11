import SwiftUI

struct ProgressDashboardView: View {
    @EnvironmentObject private var store: ClockStore
    @AppStorage("Clockin.Theme") private var themeRaw = ClockinThemeChoice.carbon.rawValue
    @AppStorage("Clockin.MascotEnabled") private var mascotEnabled = true
    @AppStorage("Clockin.GoalDailyHours") private var dailyGoalHours = 0.0
    @AppStorage("Clockin.GoalMonthlyHours") private var monthlyGoalHours = 0.0
    @State private var tab = 0
    @State private var now = Date()
    let onBack: () -> Void
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private var theme: ClockinPalette { ClockinThemeChoice.selected(themeRaw).palette }

    private var totalHours: Double { (store.totalDuration + store.elapsed(at: now)) / 3600 }
    private var xp: Int { Int(totalHours * 100) }
    private var level: Int { max(1, xp / 500 + 1) }
    private var levelProgress: Double { Double(xp % 500) / 500 }
    private var streak: Int {
        let days = Set(store.sessions.map { Calendar.current.startOfDay(for: $0.start) } + (store.running.map { [Calendar.current.startOfDay(for: $0.start)] } ?? []))
        var cursor = Calendar.current.startOfDay(for: now)
        if !days.contains(cursor) { cursor = Calendar.current.date(byAdding: .day, value: -1, to: cursor) ?? cursor }
        var count = 0
        while days.contains(cursor) { count += 1; cursor = Calendar.current.date(byAdding: .day, value: -1, to: cursor) ?? cursor }
        return count
    }
    private var avatar: String { ["🌱", "⚡️", "🚀", "🪐", "👑"][min((level - 1) / 3, 4)] }

    var body: some View {
        VStack(spacing: 0) {
            HStack { Button(action: onBack) { Image(systemName: "chevron.left").frame(width: 26, height: 26) }.buttonStyle(.plain); Text("PROGRESS").font(.system(size: 13, weight: .black)).tracking(1.3); Spacer() }
                .padding(.horizontal, 15).frame(height: 50).overlay(alignment: .bottom) { Divider().opacity(0.25) }
            Picker("", selection: $tab) { Text("Overview").tag(0); Text("Badges").tag(1); Text("Records").tag(2); Text("Weekly").tag(3); Text("Reports").tag(4) }.pickerStyle(.segmented).padding(16)
            ScrollView { Group { if tab == 0 { overview } else if tab == 1 { badges } else if tab == 2 { records } else if tab == 3 { weekly } else { reports } }.padding(.horizontal, 16).padding(.bottom, 16) }
        }
        .fontDesign(theme.fontDesign).onReceive(timer) { now = $0 }
    }

    private var overview: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) { if mascotEnabled { MascotView(store: store, now: now, level: level) }; VStack(alignment: .leading, spacing: 4) { Text("LEVEL \(level)").font(.system(size: 18, weight: .black)); Text("\(xp) XP • \(500 - xp % 500) XP to next level").font(.system(size: 10)).foregroundStyle(.secondary); ProgressView(value: levelProgress).tint(theme.accent).frame(width: 180) }; Spacer() }.padding(16).background(card)
            HStack { stat("🔥", "STREAK", "\(streak) day\(streak == 1 ? "" : "s")"); Divider(); stat("⏱", "TOTAL", DurationText.compact(store.totalDuration + store.elapsed(at: now))); Divider(); stat("⚡", "XP RATE", "100 / hour") }.padding(13).background(card)
            goalETA
        }
    }

    private var records: some View {
        let longest = store.sessions.map(\.duration).max() ?? 0
        let bestDay = Dictionary(grouping: store.sessions) { Calendar.current.startOfDay(for: $0.start) }.mapValues { $0.reduce(0) { $0 + $1.duration } }.max { $0.value < $1.value }?.value ?? 0
        return VStack(spacing: 9) { record("trophy.fill", "Longest session", DurationText.compact(longest)); record("calendar.badge.exclamationmark", "Best day", DurationText.compact(bestDay)); record("flame.fill", "Current streak", "\(streak) days"); record("star.fill", "Total XP", "\(xp) XP") }
    }

    private var badges: some View {
        let total = totalHours
        let earned: [(String, String, String, Bool)] = [
            ("first", "First session", "Complete your first session", total > 0),
            ("ten", "10-hour club", "Work 10 total hours", total >= 10),
            ("fifty", "Half-century", "Work 50 total hours", total >= 50),
            ("hundred", "Century", "Work 100 total hours", total >= 100),
            ("quarter", "Quarter kilo", "Work 250 total hours", total >= 250),
            ("streak", "On a roll", "Keep a 3-day streak", streak >= 3),
            ("weekstreak", "Weekly fire", "Keep a 7-day streak", streak >= 7),
            ("monthstreak", "Unstoppable", "Keep a 30-day streak", streak >= 30),
            ("week", "Weekly finisher", "Log 7 sessions", store.sessions.count >= 7),
            ("sessions25", "Session collector", "Log 25 sessions", store.sessions.count >= 25),
            ("marathon", "Marathon", "Complete a 4-hour session", (store.sessions.map(\.duration).max() ?? 0) >= 4 * 3600),
            ("ultra", "Ultra focus", "Complete an 8-hour session", (store.sessions.map(\.duration).max() ?? 0) >= 8 * 3600),
            ("xp", "XP engine", "Earn 10,000 XP", xp >= 10_000)
        ]
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(earned, id: \.0) { badge in
                VStack(spacing: 7) { Text(badge.3 ? "🏅" : "🔒").font(.system(size: 27)); Text(badge.1).font(.system(size: 10, weight: .bold)); Text(badge.3 ? "Unlocked" : badge.2).font(.system(size: 8)).foregroundStyle(badge.3 ? theme.accent : .secondary).multilineTextAlignment(.center) }.frame(maxWidth: .infinity, minHeight: 100).padding(8).background(card).opacity(badge.3 ? 1 : 0.65)
            }
        }
    }

    private var reports: some View {
        let cal = Calendar.current
        let activeDays = Set(store.sessions.map { cal.startOfDay(for: $0.start) }).count
        let sessionAverage = store.sessions.isEmpty ? 0 : store.sessions.reduce(0) { $0 + $1.duration } / Double(store.sessions.count)
        let weekdayTotals = Dictionary(grouping: store.sessions) { cal.component(.weekday, from: $0.start) }.mapValues { $0.reduce(0) { $0 + $1.duration } }
        let bestWeekday = weekdayTotals.max { $0.value < $1.value }.map { cal.weekdaySymbols[$0.key - 1] } ?? "—"
        let hourTotals = Dictionary(grouping: store.sessions) { cal.component(.hour, from: $0.start) }.mapValues { $0.reduce(0) { $0 + $1.duration } }
        let bestHour = hourTotals.max { $0.value < $1.value }.map { String(format: "%02d:00", $0.key) } ?? "—"
        let totalDuration = store.totalDuration + store.elapsed(at: now)
        let hourlyEarning = totalDuration > 0 ? store.allEarnings(at: now) / totalDuration * 3600 : 0
        let recentCutoff = now.addingTimeInterval(-30 * 86_400)
        let recent = store.sessions.filter { $0.start >= recentCutoff }.reduce(0) { $0 + $1.duration }
        let prior = store.sessions.filter { $0.start >= now.addingTimeInterval(-60 * 86_400) && $0.start < recentCutoff }.reduce(0) { $0 + $1.duration }
        let trend = prior > 0 ? (recent - prior) / prior : (recent > 0 ? 1 : 0)
        return VStack(spacing: 9) {
            reportMetric("ACTIVE DAYS", "\(activeDays)")
            reportMetric("AVERAGE SESSION", DurationText.compact(sessionAverage))
            reportMetric("BEST WEEKDAY", bestWeekday)
            reportMetric("BEST START HOUR", bestHour)
            reportMetric("AVERAGE EARNINGS / HOUR", store.currencyCode == "USD" ? hourlyEarning.money(code: store.currencyCode) : hourlyEarning.money(code: store.currencyCode))
            reportMetric("LAST 30D TREND", String(format: "%+.0f%%", trend * 100))
            Text("Reports are calculated from completed sessions and update after each clock-out.").font(.system(size: 9)).foregroundStyle(.tertiary).frame(maxWidth: .infinity, alignment: .leading).padding(10)
        }
    }

    private var weekly: some View {
        let cal = Calendar.current; let start = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: now)) ?? now
        let current = store.sessions.filter { $0.start >= start }.reduce(0) { $0 + $1.duration } + (store.running?.elapsed(at: now) ?? 0)
        let previousStart = cal.date(byAdding: .day, value: -13, to: cal.startOfDay(for: now)) ?? now
        let previous = store.sessions.filter { $0.start >= previousStart && $0.start < start }.reduce(0) { $0 + $1.duration }
        let delta = previous > 0 ? (current - previous) / previous : 1
        return VStack(spacing: 12) { reportMetric("THIS WEEK", DurationText.compact(current)); reportMetric("LAST WEEK", DurationText.compact(previous)); reportMetric("CHANGE", String(format: "%+.0f%%", delta * 100)); Text("Keep the streak alive and beat your previous week.").font(.system(size: 11)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(12).background(card) }
    }

    private var goalETA: some View {
        let today = store.todayDuration(at: now) / 3600
        let remaining = max(0, dailyGoalHours - today)
        let recent = store.sessions.filter { $0.start >= now.addingTimeInterval(-7 * 86_400) }.reduce(0) { $0 + $1.duration } / 3600 / 7
        return VStack(alignment: .leading, spacing: 6) {
            Text("TARGET ETA").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary).tracking(1)
            if dailyGoalHours <= 0 && monthlyGoalHours <= 0 { Text("Set a daily or monthly goal in Settings.").font(.system(size: 11)).foregroundStyle(.secondary) }
            else if dailyGoalHours > 0 && remaining <= 0 { Text("Daily goal reached 🎉").font(.system(size: 11, weight: .semibold)).foregroundStyle(theme.accent) }
            else if let running = store.running, !running.isPaused, dailyGoalHours > 0 {
                Text("At the current pace, today’s goal lands around \(now.addingTimeInterval(remaining * 3600).formatted(date: .omitted, time: .shortened)).").font(.system(size: 11))
            } else if dailyGoalHours > 0, recent > 0 {
                Text("At your 7-day average, today’s goal is about \(Int(ceil(remaining / recent))) day(s) away.").font(.system(size: 11))
            } else { Text("Start working to generate a live finish estimate.").font(.system(size: 11)).foregroundStyle(.secondary) }
        }.padding(12).background(card)
    }
    private func stat(_ icon: String, _ title: String, _ value: String) -> some View { VStack(spacing: 4) { Text(icon); Text(title).font(.system(size: 7, weight: .bold)).foregroundStyle(.secondary); Text(value).font(.system(size: 10, weight: .semibold, design: .monospaced)) }.frame(maxWidth: .infinity) }
    private func record(_ icon: String, _ title: String, _ value: String) -> some View { HStack { Image(systemName: icon).foregroundStyle(theme.accent).frame(width: 22); Text(title).font(.system(size: 11, weight: .semibold)); Spacer(); Text(value).font(.system(size: 11, weight: .bold, design: .monospaced)) }.padding(13).background(card) }
    private func reportMetric(_ title: String, _ value: String) -> some View { HStack { Text(title).font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary).tracking(1); Spacer(); Text(value).font(.system(size: 16, weight: .bold, design: .rounded)) }.padding(14).background(card) }
    private var card: some ShapeStyle { .black.opacity(0.16) }
}

private struct MascotView: View {
    @ObservedObject var store: ClockStore
    let now: Date
    let level: Int
    @AppStorage("Clockin.MascotEnabled") private var enabled = true
    private var asset: String {
        guard let running = store.running else { return "idle" }
        if !running.isPaused && Int(now.timeIntervalSince1970) % 20 >= 17 { return "celebrate" }
        return running.isPaused ? "paused" : "working"
    }
    var body: some View {
        Group {
            ClockinMascotStage().environmentObject(store)
        }
        .frame(width: 72, height: 72)
            .shadow(color: .cyan.opacity(0.22), radius: 8)
    }
}
