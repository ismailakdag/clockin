import SwiftUI

private struct ProgressBadge: Identifiable {
    let id: String
    let title: String
    let requirement: String
    let icon: String
    let color: Color
    let unlocked: Bool
}

struct ProgressDashboardView: View {
    @EnvironmentObject private var store: ClockStore
    @AppStorage("Clockin.Theme") private var themeRaw = ClockinThemeChoice.carbon.rawValue
    @AppStorage("Clockin.MascotEnabled") private var mascotEnabled = true
    @AppStorage("Clockin.GoalDailyHours") private var dailyGoalHours = 0.0
    @AppStorage("Clockin.GoalMonthlyHours") private var monthlyGoalHours = 0.0
    @State private var tab = 0
    @State private var now = Date()
    @State private var showShareStats = false
    let onBack: () -> Void
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private var theme: ClockinPalette { ClockinThemeChoice.selected(themeRaw).palette }

    private var totalHours: Double { (store.totalDuration + store.elapsed(at: now)) / 3600 }
    private var dailyDurations: [Date: TimeInterval] {
        let calendar = Calendar.current
        var values: [Date: TimeInterval] = [:]
        for session in store.sessions {
            let day = calendar.startOfDay(for: session.start)
            values[day, default: 0] += session.duration
        }
        if let running = store.running {
            values[calendar.startOfDay(for: running.start), default: 0] += running.elapsed(at: now)
        }
        return values
    }
    private var baseXP: Int { Int(totalHours * 100) }
    private var completedGoalDays: Int {
        guard dailyGoalHours > 0 else { return 0 }
        return dailyDurations.values.filter { $0 >= dailyGoalHours * 3600 }.count
    }
    private var doubleGoalDays: Int {
        guard dailyGoalHours > 0 else { return 0 }
        return dailyDurations.values.filter { $0 >= dailyGoalHours * 7200 }.count
    }
    private var completedGoalMonths: Int {
        guard monthlyGoalHours > 0 else { return 0 }
        let calendar = Calendar.current
        let monthly = Dictionary(grouping: dailyDurations) { calendar.dateInterval(of: .month, for: $0.key)?.start ?? $0.key }
        return monthly.values.map { $0.reduce(0) { $0 + $1.value } }.filter { $0 >= monthlyGoalHours * 3600 }.count
    }
    private var longestStreak: Int {
        let calendar = Calendar.current
        let days = dailyDurations.keys.sorted()
        guard !days.isEmpty else { return 0 }
        var best = 1
        var current = 1
        for pair in zip(days, days.dropFirst()) {
            if calendar.dateComponents([.day], from: pair.0, to: pair.1).day == 1 {
                current += 1
                best = max(best, current)
            } else {
                current = 1
            }
        }
        return best
    }
    private var goalBonusXP: Int { completedGoalDays * 100 + doubleGoalDays * 250 + completedGoalMonths * 500 }
    private var streakBonusXP: Int {
        [(3, 100), (7, 250), (14, 500), (30, 1_000), (60, 2_000)]
            .filter { longestStreak >= $0.0 }
            .reduce(0) { $0 + $1.1 }
    }
    private var xp: Int { baseXP + goalBonusXP + streakBonusXP }
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
            HStack { Button(action: onBack) { Image(systemName: "chevron.left").frame(width: 26, height: 26) }.buttonStyle(.plain); Text("PROGRESS").font(.system(size: 13, weight: .black)).tracking(1.3); Spacer(); Button { showShareStats = true } label: { Image(systemName: "square.and.arrow.up").frame(width: 28, height: 28) }.buttonStyle(.plain).foregroundStyle(theme.accent).help("Share stats") }
                .padding(.horizontal, 15).frame(height: 50).overlay(alignment: .bottom) { Divider().opacity(0.25) }
            Picker("", selection: $tab) { Text("Overview").tag(0); Text("Badges").tag(1); Text("Records").tag(2); Text("Weekly").tag(3); Text("Reports").tag(4) }.pickerStyle(.segmented).padding(16)
            ScrollView { Group { if tab == 0 { overview } else if tab == 1 { badges } else if tab == 2 { records } else if tab == 3 { weekly } else { reports } }.padding(.horizontal, 16).padding(.bottom, 16) }
        }
        .fontDesign(theme.fontDesign).onReceive(timer) { now = $0 }
        .sheet(isPresented: $showShareStats) {
            ShareStatsView().environmentObject(store).environmentObject(AppDependencies.shared.exchangeRates)
        }
    }

    private var overview: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) { if mascotEnabled { MascotView(store: store, now: now, level: level) }; VStack(alignment: .leading, spacing: 4) { Text("LEVEL \(level)").font(.system(size: 18, weight: .black)); Text("\(xp) XP • \(500 - xp % 500) XP to next level").font(.system(size: 10)).foregroundStyle(.secondary); ProgressView(value: levelProgress).tint(theme.accent).frame(width: 180); Text("Base \(baseXP) • Goal +\(goalBonusXP) • Streak +\(streakBonusXP)").font(.system(size: 8, design: .monospaced)).foregroundStyle(theme.accent) }; Spacer() }.padding(16).background(card)
            HStack { stat("🔥", "STREAK", "\(streak) day\(streak == 1 ? "" : "s")"); Divider(); stat("⏱", "TOTAL", DurationText.compact(store.totalDuration + store.elapsed(at: now))); Divider(); stat("⚡", "XP RATE", "100 / hour + bonus") }.padding(13).background(card)
            goalBonusCard
            goalETA
        }
    }

    private var goalBonusCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("BONUS ENGINE").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary).tracking(1)
            if dailyGoalHours <= 0 && monthlyGoalHours <= 0 {
                Text("Set daily or monthly goals to earn bonus XP.").font(.system(size: 10)).foregroundStyle(.secondary)
            } else {
                Text("+\(goalBonusXP) XP from goals • \(completedGoalDays) daily • \(doubleGoalDays) double-goal • \(completedGoalMonths) monthly")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(theme.accent)
                Text("A completed day gives +100 XP; a 2× goal day gives an additional +250 XP.")
                    .font(.system(size: 8)).foregroundStyle(.tertiary)
            }
        }.padding(12).background(card)
    }

    private var records: some View {
        let longest = store.sessions.map(\.duration).max() ?? 0
        let bestDay = Dictionary(grouping: store.sessions) { Calendar.current.startOfDay(for: $0.start) }.mapValues { $0.reduce(0) { $0 + $1.duration } }.max { $0.value < $1.value }?.value ?? 0
        return VStack(spacing: 9) { record("trophy.fill", "Longest session", DurationText.compact(longest)); record("calendar.badge.exclamationmark", "Best day", DurationText.compact(bestDay)); record("flame.fill", "Current streak", "\(streak) days"); record("flame.circle.fill", "Longest streak", "\(longestStreak) days"); record("target", "Goal days", "\(completedGoalDays)"); record("star.fill", "Total XP", "\(xp) XP") }
    }

    private var badges: some View {
        let total = totalHours
        let earned: [ProgressBadge] = [
            .init(id: "first", title: "First session", requirement: "Complete your first session", icon: "flag.fill", color: .green, unlocked: total > 0),
            .init(id: "ten", title: "10-hour club", requirement: "Work 10 total hours", icon: "clock.fill", color: .blue, unlocked: total >= 10),
            .init(id: "fifty", title: "Half-century", requirement: "Work 50 total hours", icon: "flame.fill", color: .orange, unlocked: total >= 50),
            .init(id: "hundred", title: "Century", requirement: "Work 100 total hours", icon: "bolt.fill", color: .yellow, unlocked: total >= 100),
            .init(id: "quarter", title: "Quarter kilo", requirement: "Work 250 total hours", icon: "crown.fill", color: .purple, unlocked: total >= 250),
            .init(id: "streak", title: "On a roll", requirement: "Keep a 3-day streak", icon: "flame.circle.fill", color: .orange, unlocked: streak >= 3),
            .init(id: "weekstreak", title: "Weekly fire", requirement: "Keep a 7-day streak", icon: "calendar.badge.clock", color: .red, unlocked: streak >= 7),
            .init(id: "monthstreak", title: "Unstoppable", requirement: "Keep a 30-day streak", icon: "infinity", color: .pink, unlocked: streak >= 30),
            .init(id: "streak14", title: "Fortnight fire", requirement: "Reach a 14-day streak", icon: "sparkles", color: .cyan, unlocked: longestStreak >= 14),
            .init(id: "streak60", title: "Seasoned", requirement: "Reach a 60-day streak", icon: "mountain.2.fill", color: .indigo, unlocked: longestStreak >= 60),
            .init(id: "week", title: "Weekly finisher", requirement: "Log 7 sessions", icon: "calendar.badge.plus", color: .teal, unlocked: store.sessions.count >= 7),
            .init(id: "sessions25", title: "Session collector", requirement: "Log 25 sessions", icon: "square.stack.3d.up.fill", color: .mint, unlocked: store.sessions.count >= 25),
            .init(id: "marathon", title: "Marathon", requirement: "Complete a 4-hour session", icon: "figure.run", color: .orange, unlocked: (store.sessions.map(\.duration).max() ?? 0) >= 4 * 3600),
            .init(id: "ultra", title: "Ultra focus", requirement: "Complete an 8-hour session", icon: "bolt.circle.fill", color: .yellow, unlocked: (store.sessions.map(\.duration).max() ?? 0) >= 8 * 3600),
            .init(id: "xp", title: "XP engine", requirement: "Earn 10,000 XP", icon: "star.fill", color: .yellow, unlocked: xp >= 10_000),
            .init(id: "goal", title: "Goal setter", requirement: "Complete a daily goal", icon: "target", color: .green, unlocked: completedGoalDays >= 1),
            .init(id: "doublegoal", title: "Double down", requirement: "Reach 2× a daily goal", icon: "arrow.up.right.circle.fill", color: .blue, unlocked: doubleGoalDays >= 1),
            .init(id: "monthgoal", title: "Month finisher", requirement: "Complete a monthly goal", icon: "calendar.circle.fill", color: .purple, unlocked: completedGoalMonths >= 1),
            .init(id: "xp25", title: "Quarter XP", requirement: "Earn 25,000 XP", icon: "rosette", color: .pink, unlocked: xp >= 25_000)
        ]
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(earned) { badge in
                VStack(spacing: 7) {
                    ZStack(alignment: .bottomTrailing) {
                        Image(systemName: badge.icon).font(.system(size: 26, weight: .bold)).foregroundStyle(badge.unlocked ? badge.color : .secondary)
                        if !badge.unlocked { Image(systemName: "lock.fill").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary).padding(2).background(.thinMaterial, in: Circle()) }
                    }
                    Text(badge.title).font(.system(size: 10, weight: .bold))
                    Text(badge.unlocked ? "Unlocked • \(badge.requirement)" : badge.requirement)
                        .font(.system(size: 8)).foregroundStyle(badge.unlocked ? theme.accent : .secondary)
                        .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.78)
                }
                .frame(maxWidth: .infinity, minHeight: 100).padding(8).background(card).opacity(badge.unlocked ? 1 : 0.65)
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
