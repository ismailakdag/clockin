import SwiftUI

private struct ProgressBadge: Identifiable {
    let id: String
    let title: String
    let requirement: String
    let icon: String
    let color: Color
    let unlocked: Bool
    let progress: String

    init(id: String, title: String, requirement: String, icon: String, color: Color, unlocked: Bool, progress: String = "") {
        self.id = id
        self.title = title
        self.requirement = requirement
        self.icon = icon
        self.color = color
        self.unlocked = unlocked
        self.progress = progress
    }
}

struct ProgressDashboardView: View {
    @AppStorage(UIScale.key) private var uiScaleObserver = 1.0
    @EnvironmentObject private var store: ClockStore
    @AppStorage("Clockin.Theme") private var themeRaw = ClockinThemeChoice.carbon.rawValue
    @AppStorage("Clockin.MascotEnabled") private var mascotEnabled = true
    @AppStorage("Clockin.GoalDailyHours") private var dailyGoalHours = 0.0
    @AppStorage("Clockin.GoalMonthlyHours") private var monthlyGoalHours = 0.0
    @State private var tab = 0
    @State private var now = Date()
    @State private var showShareStats = false
    @State private var selectedBadge: ProgressBadge?
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
    private var activeDays: Int { dailyDurations.count }
    private var longestSession: TimeInterval { store.sessions.map(\.duration).max() ?? 0 }
    private var earlyBirdSessions: Int { store.sessions.filter { Calendar.current.component(.hour, from: $0.start) < 8 }.count }
    private var nightOwlSessions: Int { store.sessions.filter { Calendar.current.component(.hour, from: $0.start) >= 22 }.count }
    private var weekendDays: Int {
        Set(store.sessions.filter { [1, 7].contains(Calendar.current.component(.weekday, from: $0.start)) }.map { Calendar.current.startOfDay(for: $0.start) }).count
    }

    var body: some View {
        VStack(spacing: S(0)) {
            HStack { Button(action: onBack) { Image(systemName: "chevron.left").frame(width: S(26), height: S(26)) }.buttonStyle(.plain); Text("PROGRESS").font(.system(size: S(13), weight: .black)).tracking(S(1.3)); Spacer(); Button { showShareStats = true } label: { Image(systemName: "square.and.arrow.up").frame(width: S(28), height: S(28)) }.buttonStyle(.plain).foregroundStyle(theme.accent).help("Share stats") }
                .padding(.horizontal, S(15)).frame(height: S(50)).overlay(alignment: .bottom) { Divider().opacity(0.25) }
            Picker("", selection: $tab) { Text("Overview").tag(0); Text("Badges").tag(1); Text("Records").tag(2); Text("Weekly").tag(3); Text("Reports").tag(4) }.pickerStyle(.segmented).padding(S(16))
            ScrollView { Group { if tab == 0 { overview } else if tab == 1 { badges } else if tab == 2 { records } else if tab == 3 { weekly } else { reports } }.padding(.horizontal, S(16)).padding(.bottom, S(16)) }
        }
        .fontDesign(theme.fontDesign).onReceive(timer) { now = $0 }
        .sheet(isPresented: $showShareStats) {
            ShareStatsView().environmentObject(store).environmentObject(AppDependencies.shared.exchangeRates)
        }
        .overlay {
            if let badge = selectedBadge {
                ZStack {
                    Color.black.opacity(0.34)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture { selectedBadge = nil }
                    BadgeDetailView(badge: badge, theme: theme)
                        .background(theme.background, in: RoundedRectangle(cornerRadius: S(16), style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: S(16), style: .continuous).stroke(theme.accent.opacity(0.35)))
                        .shadow(color: .black.opacity(0.35), radius: 22, y: 10)
                        .onTapGesture { }
                        .transition(.scale(scale: 0.92).combined(with: .opacity))
                }
                .zIndex(20)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: selectedBadge != nil)
    }

    private var overview: some View {
        VStack(spacing: S(12)) {
            HStack(spacing: S(14)) { if mascotEnabled { MascotView(store: store, now: now, level: level) }; VStack(alignment: .leading, spacing: S(4)) { Text("LEVEL \(level)").font(.system(size: S(18), weight: .black)); Text("\(xp) XP • \(500 - xp % 500) XP to next level").font(.system(size: S(10))).foregroundStyle(.secondary); ProgressView(value: levelProgress).tint(theme.accent).frame(width: S(180)); Text("Base \(baseXP) • Goal +\(goalBonusXP) • Streak +\(streakBonusXP)").font(.system(size: S(8), design: .monospaced)).foregroundStyle(theme.accent) }; Spacer() }.padding(S(16)).background(card)
            HStack { stat("🔥", "STREAK", "\(streak) day\(streak == 1 ? "" : "s")"); Divider(); stat("⏱", "TOTAL", DurationText.compact(store.totalDuration + store.elapsed(at: now))); Divider(); stat("⚡", "XP RATE", "100 / hour + bonus") }.padding(S(13)).background(card)
            goalBonusCard
            goalETA
        }
    }

    private var goalBonusCard: some View {
        VStack(alignment: .leading, spacing: S(6)) {
            Text("BONUS ENGINE").font(.system(size: S(9), weight: .bold)).foregroundStyle(.secondary).tracking(S(1))
            if dailyGoalHours <= 0 && monthlyGoalHours <= 0 {
                Text("Set daily or monthly goals to earn bonus XP.").font(.system(size: S(10))).foregroundStyle(.secondary)
            } else {
                Text("+\(goalBonusXP) XP from goals • \(completedGoalDays) daily • \(doubleGoalDays) double-goal • \(completedGoalMonths) monthly")
                    .font(.system(size: S(10), weight: .semibold, design: .monospaced)).foregroundStyle(theme.accent)
                Text("A completed day gives +100 XP; a 2× goal day gives an additional +250 XP.")
                    .font(.system(size: S(8))).foregroundStyle(.tertiary)
            }
        }.padding(S(12)).background(card)
    }

    private var records: some View {
        let longest = store.sessions.map(\.duration).max() ?? 0
        let bestDay = Dictionary(grouping: store.sessions) { Calendar.current.startOfDay(for: $0.start) }.mapValues { $0.reduce(0) { $0 + $1.duration } }.max { $0.value < $1.value }?.value ?? 0
        return VStack(spacing: S(9)) { record("trophy.fill", "Longest session", DurationText.compact(longest)); record("calendar.badge.exclamationmark", "Best day", DurationText.compact(bestDay)); record("flame.fill", "Current streak", "\(streak) days"); record("flame.circle.fill", "Longest streak", "\(longestStreak) days"); record("target", "Goal days", "\(completedGoalDays)"); record("star.fill", "Total XP", "\(xp) XP") }
    }

    private var badges: some View {
        let total = totalHours
        let earned: [ProgressBadge] = [
            .init(id: "first", title: "First session", requirement: "Complete your first session", icon: "flag.fill", color: .green, unlocked: total > 0, progress: String(store.sessions.count) + " sessions"),
            .init(id: "ten", title: "10-hour club", requirement: "Work 10 total hours", icon: "clock.fill", color: .blue, unlocked: total >= 10, progress: progressText(DurationText.compact(total * 3600), "10h")),
            .init(id: "fifty", title: "Half-century", requirement: "Work 50 total hours", icon: "flame.fill", color: .orange, unlocked: total >= 50, progress: progressText(DurationText.compact(total * 3600), "50h")),
            .init(id: "hundred", title: "Century", requirement: "Work 100 total hours", icon: "bolt.fill", color: .yellow, unlocked: total >= 100, progress: progressText(DurationText.compact(total * 3600), "100h")),
            .init(id: "quarter", title: "Quarter kilo", requirement: "Work 250 total hours", icon: "crown.fill", color: .purple, unlocked: total >= 250, progress: progressText(DurationText.compact(total * 3600), "250h")),
            .init(id: "fivehundred", title: "Half-thousand", requirement: "Work 500 total hours", icon: "crown.fill", color: .indigo, unlocked: total >= 500, progress: progressText(DurationText.compact(total * 3600), "500h")),
            .init(id: "sevenfifty", title: "Three-quarter legend", requirement: "Work 750 total hours", icon: "medal.fill", color: .mint, unlocked: total >= 750, progress: progressText(DurationText.compact(total * 3600), "750h")),
            .init(id: "thousand", title: "Thousand-hour", requirement: "Work 1,000 total hours", icon: "trophy.fill", color: .yellow, unlocked: total >= 1_000, progress: progressText(DurationText.compact(total * 3600), "1,000h")),
            .init(id: "titan", title: "Time titan", requirement: "Work 1,500 total hours", icon: "diamond.fill", color: .pink, unlocked: total >= 1_500, progress: progressText(DurationText.compact(total * 3600), "1,500h")),
            .init(id: "streak", title: "On a roll", requirement: "Keep a 3-day streak", icon: "flame.circle.fill", color: .orange, unlocked: streak >= 3, progress: progressText(String(streak), "3 days")),
            .init(id: "weekstreak", title: "Weekly fire", requirement: "Keep a 7-day streak", icon: "calendar.badge.clock", color: .red, unlocked: streak >= 7, progress: progressText(String(streak), "7 days")),
            .init(id: "monthstreak", title: "Unstoppable", requirement: "Keep a 30-day streak", icon: "infinity", color: .pink, unlocked: streak >= 30, progress: progressText(String(streak), "30 days")),
            .init(id: "streak14", title: "Fortnight fire", requirement: "Reach a 14-day streak", icon: "sparkles", color: .cyan, unlocked: longestStreak >= 14, progress: progressText(String(longestStreak), "14 days")),
            .init(id: "streak60", title: "Seasoned", requirement: "Reach a 60-day streak", icon: "mountain.2.fill", color: .indigo, unlocked: longestStreak >= 60, progress: progressText(String(longestStreak), "60 days")),
            .init(id: "week", title: "Weekly finisher", requirement: "Log 7 sessions", icon: "calendar.badge.plus", color: .teal, unlocked: store.sessions.count >= 7, progress: progressText(String(store.sessions.count), "7 sessions")),
            .init(id: "sessions25", title: "Session collector", requirement: "Log 25 sessions", icon: "square.stack.3d.up.fill", color: .mint, unlocked: store.sessions.count >= 25, progress: progressText(String(store.sessions.count), "25 sessions")),
            .init(id: "marathon", title: "Marathon", requirement: "Complete a 4-hour session", icon: "figure.run", color: .orange, unlocked: longestSession >= 4 * 3600, progress: progressText(DurationText.compact(longestSession), "4h")),
            .init(id: "ultra", title: "Ultra focus", requirement: "Complete an 8-hour session", icon: "bolt.circle.fill", color: .yellow, unlocked: longestSession >= 8 * 3600, progress: progressText(DurationText.compact(longestSession), "8h")),
            .init(id: "xp", title: "XP engine", requirement: "Earn 10,000 XP", icon: "star.fill", color: .yellow, unlocked: xp >= 10_000, progress: progressText(String(xp), "10,000 XP")),
            .init(id: "goal", title: "Goal setter", requirement: "Complete a daily goal", icon: "target", color: .green, unlocked: completedGoalDays >= 1, progress: String(completedGoalDays) + " goal days"),
            .init(id: "doublegoal", title: "Double down", requirement: "Reach 2× a daily goal", icon: "arrow.up.right.circle.fill", color: .blue, unlocked: doubleGoalDays >= 1, progress: String(doubleGoalDays) + " double-goal days"),
            .init(id: "monthgoal", title: "Month finisher", requirement: "Complete a monthly goal", icon: "calendar.circle.fill", color: .purple, unlocked: completedGoalMonths >= 1, progress: String(completedGoalMonths) + " goal months"),
            .init(id: "xp25", title: "Quarter XP", requirement: "Earn 25,000 XP", icon: "rosette", color: .pink, unlocked: xp >= 25_000, progress: progressText(String(xp), "25,000 XP")),
            .init(id: "active5", title: "Getting steady", requirement: "Work on 5 different days", icon: "calendar", color: .teal, unlocked: activeDays >= 5, progress: progressText(String(activeDays), "5 active days")),
            .init(id: "active25", title: "Calendar regular", requirement: "Work on 25 different days", icon: "calendar.badge.checkmark", color: .green, unlocked: activeDays >= 25, progress: progressText(String(activeDays), "25 active days")),
            .init(id: "active100", title: "Daily craft", requirement: "Work on 100 different days", icon: "calendar.circle", color: .blue, unlocked: activeDays >= 100, progress: progressText(String(activeDays), "100 active days")),
            .init(id: "earlybird", title: "Early bird", requirement: "Start 5 sessions before 08:00", icon: "sunrise.fill", color: .yellow, unlocked: earlyBirdSessions >= 5, progress: progressText(String(earlyBirdSessions), "5 early starts")),
            .init(id: "nightowl", title: "Night owl", requirement: "Start 5 sessions after 22:00", icon: "moon.stars.fill", color: .indigo, unlocked: nightOwlSessions >= 5, progress: progressText(String(nightOwlSessions), "5 late starts")),
            .init(id: "weekend", title: "Weekend warrior", requirement: "Work on 4 weekend days", icon: "sun.max.fill", color: .orange, unlocked: weekendDays >= 4, progress: progressText(String(weekendDays), "4 weekend days")),
            .init(id: "sessions50", title: "Deep archive", requirement: "Log 50 sessions", icon: "books.vertical.fill", color: .purple, unlocked: store.sessions.count >= 50, progress: progressText(String(store.sessions.count), "50 sessions")),
            .init(id: "sessions100", title: "Century sessions", requirement: "Log 100 sessions", icon: "building.columns.fill", color: .pink, unlocked: store.sessions.count >= 100, progress: progressText(String(store.sessions.count), "100 sessions")),
            .init(id: "sessions200", title: "Archive master", requirement: "Log 200 sessions", icon: "square.stack.3d.up.fill", color: .indigo, unlocked: store.sessions.count >= 200, progress: progressText(String(store.sessions.count), "200 sessions")),
            .init(id: "sessions500", title: "Session institution", requirement: "Log 500 sessions", icon: "building.2.crop.circle.fill", color: .yellow, unlocked: store.sessions.count >= 500, progress: progressText(String(store.sessions.count), "500 sessions")),
            .init(id: "ultra12", title: "Iron focus", requirement: "Complete a 12-hour session", icon: "hourglass.bottomhalf.filled", color: .red, unlocked: longestSession >= 12 * 3600, progress: progressText(DurationText.compact(longestSession), "12h")),
            .init(id: "ultra15", title: "Deep dive", requirement: "Complete a 15-hour session", icon: "water.waves", color: .cyan, unlocked: longestSession >= 15 * 3600, progress: progressText(DurationText.compact(longestSession), "15h")),
            .init(id: "goal7", title: "Goal rhythm", requirement: "Complete daily goals on 7 days", icon: "checkmark.seal.fill", color: .mint, unlocked: completedGoalDays >= 7, progress: progressText(String(completedGoalDays), "7 goal days")),
            .init(id: "goal30", title: "Goal machine", requirement: "Complete daily goals on 30 days", icon: "target", color: .green, unlocked: completedGoalDays >= 30, progress: progressText(String(completedGoalDays), "30 goal days")),
            .init(id: "month3", title: "Quarter planner", requirement: "Complete 3 monthly goals", icon: "calendar.badge.checkmark", color: .blue, unlocked: completedGoalMonths >= 3, progress: progressText(String(completedGoalMonths), "3 goal months")),
            .init(id: "month12", title: "Year planner", requirement: "Complete 12 monthly goals", icon: "calendar.badge.clock", color: .purple, unlocked: completedGoalMonths >= 12, progress: progressText(String(completedGoalMonths), "12 goal months")),
            .init(id: "streak90", title: "Season streak", requirement: "Reach a 90-day streak", icon: "flame.circle.fill", color: .orange, unlocked: longestStreak >= 90, progress: progressText(String(longestStreak), "90 days")),
            .init(id: "streak180", title: "Half-year fire", requirement: "Reach a 180-day streak", icon: "sun.max.fill", color: .yellow, unlocked: longestStreak >= 180, progress: progressText(String(longestStreak), "180 days")),
            .init(id: "streak365", title: "Year-round", requirement: "Reach a 365-day streak", icon: "globe.americas.fill", color: .mint, unlocked: longestStreak >= 365, progress: progressText(String(longestStreak), "365 days")),
            .init(id: "active250", title: "Always on", requirement: "Work on 250 different days", icon: "calendar.badge.clock", color: .teal, unlocked: activeDays >= 250, progress: progressText(String(activeDays), "250 active days")),
            .init(id: "active500", title: "Permanent practice", requirement: "Work on 500 different days", icon: "calendar.circle.fill", color: .pink, unlocked: activeDays >= 500, progress: progressText(String(activeDays), "500 active days")),
            .init(id: "xp50", title: "XP architect", requirement: "Earn 50,000 XP", icon: "star.circle.fill", color: .yellow, unlocked: xp >= 50_000, progress: progressText(String(xp), "50,000 XP")),
            .init(id: "xp100", title: "XP legend", requirement: "Earn 100,000 XP", icon: "sparkles", color: .purple, unlocked: xp >= 100_000, progress: progressText(String(xp), "100,000 XP"))
        ]
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: S(10)) {
            ForEach(earned) { badge in
                Button { selectedBadge = badge } label: {
                    VStack(spacing: S(7)) {
                    ZStack(alignment: .bottomTrailing) {
                        Image(systemName: badge.icon).font(.system(size: S(26), weight: .bold)).foregroundStyle(badge.unlocked ? badge.color : .secondary)
                        if !badge.unlocked { Image(systemName: "lock.fill").font(.system(size: S(9), weight: .bold)).foregroundStyle(.secondary).padding(S(2)).background(.thinMaterial, in: Circle()) }
                    }
                    Text(badge.title).font(.system(size: S(10), weight: .bold))
                    Text(badge.unlocked ? "Unlocked • \(badge.requirement)" : badge.requirement)
                        .font(.system(size: S(8))).foregroundStyle(badge.unlocked ? theme.accent : .secondary)
                        .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.78)
                    }
                    .frame(maxWidth: .infinity, minHeight: S(100)).padding(S(8)).background(card).opacity(badge.unlocked ? 1 : 0.65)
                }
                .buttonStyle(.plain)
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
        return VStack(spacing: S(9)) {
            reportMetric("ACTIVE DAYS", "\(activeDays)")
            reportMetric("AVERAGE SESSION", DurationText.compact(sessionAverage))
            reportMetric("BEST WEEKDAY", bestWeekday)
            reportMetric("BEST START HOUR", bestHour)
            reportMetric("AVERAGE EARNINGS / HOUR", store.currencyCode == "USD" ? hourlyEarning.money(code: store.currencyCode) : hourlyEarning.money(code: store.currencyCode))
            reportMetric("LAST 30D TREND", String(format: "%+.0f%%", trend * 100))
            Text("Reports are calculated from completed sessions and update after each clock-out.").font(.system(size: S(9))).foregroundStyle(.tertiary).frame(maxWidth: .infinity, alignment: .leading).padding(S(10))
        }
    }

    private var weekly: some View {
        let cal = Calendar.current; let start = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: now)) ?? now
        let current = store.sessions.filter { $0.start >= start }.reduce(0) { $0 + $1.duration } + (store.running?.elapsed(at: now) ?? 0)
        let previousStart = cal.date(byAdding: .day, value: -13, to: cal.startOfDay(for: now)) ?? now
        let previous = store.sessions.filter { $0.start >= previousStart && $0.start < start }.reduce(0) { $0 + $1.duration }
        let delta = previous > 0 ? (current - previous) / previous : 1
        return VStack(spacing: S(12)) { reportMetric("THIS WEEK", DurationText.compact(current)); reportMetric("LAST WEEK", DurationText.compact(previous)); reportMetric("CHANGE", String(format: "%+.0f%%", delta * 100)); Text("Keep the streak alive and beat your previous week.").font(.system(size: S(11))).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(S(12)).background(card) }
    }

    private var goalETA: some View {
        let today = store.todayDuration(at: now) / 3600
        let remaining = max(0, dailyGoalHours - today)
        let recent = store.sessions.filter { $0.start >= now.addingTimeInterval(-7 * 86_400) }.reduce(0) { $0 + $1.duration } / 3600 / 7
        return VStack(alignment: .leading, spacing: S(6)) {
            Text("TARGET ETA").font(.system(size: S(9), weight: .bold)).foregroundStyle(.secondary).tracking(S(1))
            if dailyGoalHours <= 0 && monthlyGoalHours <= 0 { Text("Set a daily or monthly goal in Settings.").font(.system(size: S(11))).foregroundStyle(.secondary) }
            else if dailyGoalHours > 0 && remaining <= 0 { Text("Daily goal reached 🎉").font(.system(size: S(11), weight: .semibold)).foregroundStyle(theme.accent) }
            else if let running = store.running, !running.isPaused, dailyGoalHours > 0 {
                Text("At the current pace, today’s goal lands around \(now.addingTimeInterval(remaining * 3600).formatted(date: .omitted, time: .shortened)).").font(.system(size: S(11)))
            } else if dailyGoalHours > 0, recent > 0 {
                Text("At your 7-day average, today’s goal is about \(Int(ceil(remaining / recent))) day(s) away.").font(.system(size: S(11)))
            } else { Text("Start working to generate a live finish estimate.").font(.system(size: S(11))).foregroundStyle(.secondary) }
        }.padding(S(12)).background(card)
    }
    private func stat(_ icon: String, _ title: String, _ value: String) -> some View { VStack(spacing: S(4)) { Text(icon); Text(title).font(.system(size: S(7), weight: .bold)).foregroundStyle(.secondary); Text(value).font(.system(size: S(10), weight: .semibold, design: .monospaced)) }.frame(maxWidth: .infinity) }
    private func record(_ icon: String, _ title: String, _ value: String) -> some View { HStack { Image(systemName: icon).foregroundStyle(theme.accent).frame(width: S(22)); Text(title).font(.system(size: S(11), weight: .semibold)); Spacer(); Text(value).font(.system(size: S(11), weight: .bold, design: .monospaced)) }.padding(S(13)).background(card) }
    private func reportMetric(_ title: String, _ value: String) -> some View { HStack { Text(title).font(.system(size: S(9), weight: .bold)).foregroundStyle(.secondary).tracking(S(1)); Spacer(); Text(value).font(.system(size: S(16), weight: .bold, design: .rounded)) }.padding(S(14)).background(card) }
    private func progressText(_ current: String, _ target: String) -> String { current + " / " + target }
    private var card: some ShapeStyle { .black.opacity(0.16) }
}

private struct BadgeDetailView: View {
    let badge: ProgressBadge
    let theme: ClockinPalette

    var body: some View {
        VStack(alignment: .leading, spacing: S(10)) {
            HStack(spacing: S(10)) {
                Image(systemName: badge.icon)
                    .font(.system(size: S(25), weight: .bold))
                    .foregroundStyle(badge.unlocked ? badge.color : .secondary)
                VStack(alignment: .leading, spacing: S(2)) {
                    Text(badge.title).font(.system(size: S(14), weight: .black))
                    Text(badge.unlocked ? "UNLOCKED" : "LOCKED")
                        .font(.system(size: S(8), weight: .bold, design: .monospaced))
                        .foregroundStyle(badge.unlocked ? theme.accent : .secondary)
                }
            }
            Divider().opacity(0.2)
            Text(badge.unlocked ? "How you earned it" : "What's missing")
                .font(.system(size: S(9), weight: .bold)).foregroundStyle(.secondary).tracking(S(0.8))
            Text(badge.requirement)
                .font(.system(size: S(11), weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
            if !badge.progress.isEmpty {
                Text("Current: \(badge.progress)")
                    .font(.system(size: S(10), weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.accent)
            }
        }
        .padding(S(15))
        .frame(width: S(255), alignment: .leading)
        .background(theme.background)
        .fontDesign(theme.fontDesign)
        .preferredColorScheme(theme.colorScheme)
    }
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
        .frame(width: S(72), height: S(72))
            .shadow(color: .cyan.opacity(0.22), radius: 8)
    }
}
