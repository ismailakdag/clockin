import SwiftUI

private struct ProgressBadge: Identifiable {
    let id: String
    let title: String
    let requirement: String
    let unlocked: Bool
    let progress: String

    init(id: String, title: String, requirement: String, unlocked: Bool, progress: String = "") {
        self.id = id
        self.title = title
        self.requirement = requirement
        self.unlocked = unlocked
        self.progress = progress
    }
}

struct ProgressDashboardView: View {
    @AppStorage(UIScale.key) private var uiScaleObserver = UIScale.defaultPercent
    @EnvironmentObject private var store: ClockStore
    @AppStorage("Clockin.Theme") private var themeRaw = ClockinThemeChoice.carbon.rawValue
    @AppStorage("Clockin.MascotEnabled") private var mascotEnabled = true
    @AppStorage("Clockin.GoalDailyHours") private var dailyGoalHours = 0.0
    @AppStorage("Clockin.GoalMonthlyHours") private var monthlyGoalHours = 0.0
    @State private var tab = 0
    @State private var now = Date()
    @State private var showShareStats = false
    @State private var selectedBadge: ProgressBadge?
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private var theme: ClockinPalette { ClockinThemeChoice.selected(themeRaw).palette }

    private var totalHours: Double { (store.totalDuration + store.elapsed(at: now)) / 3600 }
    private var dailyDurations: [Date: TimeInterval] {
        var values = store.dailyDurations
        if let running = store.running {
            values[Calendar.current.startOfDay(for: running.start), default: 0] += running.elapsed(at: now)
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
    private var activeDays: Int { dailyDurations.count }
    private var longestSession: TimeInterval { store.sessions.map(\.duration).max() ?? 0 }
    private var earlyBirdSessions: Int { store.sessions.filter { Calendar.current.component(.hour, from: $0.start) < 8 }.count }
    private var nightOwlSessions: Int { store.sessions.filter { Calendar.current.component(.hour, from: $0.start) >= 22 }.count }
    private var weekendDays: Int {
        Set(store.sessions.filter { [1, 7].contains(Calendar.current.component(.weekday, from: $0.start)) }.map { Calendar.current.startOfDay(for: $0.start) }).count
    }

    /// Also lets previews render every section without changing user preferences.
    init(initialTab: Int = 0) {
        _tab = State(initialValue: initialTab)
    }

    var body: some View {
        VStack(spacing: S(0)) {
            ClockinScreenHeader(title: "Progress") {
                Button { showShareStats = true } label: { Image(systemName: "square.and.arrow.up") }
                    .buttonStyle(.clockinIcon(tint: theme.accent))
                    .help("Share stats").accessibilityLabel("Share stats")
            }
            ClockinSegmented(selection: $tab, options: [(0, "Overview"), (1, "Badges"), (2, "Records"), (3, "Weekly"), (4, "Reports")])
                .padding(.horizontal, S(16)).padding(.bottom, S(12))
            ScrollView { Group { if tab == 0 { overview } else if tab == 1 { badges } else if tab == 2 { records } else if tab == 3 { weekly } else { reports } }.padding(.horizontal, S(16)).padding(.bottom, S(16)) }
        }
        .fontDesign(theme.fontDesign)
        .clockinTextStyles().onReceive(timer) { now = $0 }
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
            HStack(spacing: S(14)) { if mascotEnabled { MascotView(store: store, now: now, level: level) }; VStack(alignment: .leading, spacing: S(4)) { Text("Level \(level)").font(.system(size: S(18), weight: .black)); Text("\(xp) XP • \(500 - xp % 500) XP to next level").font(.system(size: S(10))).foregroundStyle(.secondary); ProgressView(value: levelProgress).tint(theme.accent).frame(maxWidth: .infinity); Text("Base \(baseXP) • Goal +\(goalBonusXP) • Streak +\(streakBonusXP)").font(.system(size: S(10), design: .monospaced)).foregroundStyle(theme.accent) }; Spacer() }.padding(S(16)).background(card)
            HStack { stat("Streak", "\(streak) day\(streak == 1 ? "" : "s")"); Divider(); stat("Total", DurationText.compact(store.totalDuration + store.elapsed(at: now))); Divider(); stat("XP rate", "100 / hour + bonus") }.padding(S(13)).background(card)
            goalBonusCard
            goalETA
        }
    }

    private var goalBonusCard: some View {
        VStack(alignment: .leading, spacing: S(6)) {
            Text("Goal bonuses").font(ClockinFont.section).foregroundStyle(.secondary)
            if dailyGoalHours <= 0 && monthlyGoalHours <= 0 {
                Text("Set daily or monthly goals to earn bonus XP.").font(.system(size: S(10))).foregroundStyle(.secondary)
            } else {
                Text("+\(goalBonusXP) XP from goals • \(completedGoalDays) daily • \(doubleGoalDays) double-goal • \(completedGoalMonths) monthly")
                    .font(.system(size: S(10), weight: .semibold, design: .monospaced)).foregroundStyle(theme.accent)
                Text("A completed day gives +100 XP; a 2× goal day gives an additional +250 XP.")
                    .font(.system(size: S(10))).foregroundStyle(.secondary)
            }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(S(12)).background(card)
    }

    private var records: some View {
        let longest = store.sessions.map(\.duration).max() ?? 0
        let bestDay = Dictionary(grouping: store.sessions) { Calendar.current.startOfDay(for: $0.start) }.mapValues { $0.reduce(0) { $0 + $1.duration } }.max { $0.value < $1.value }?.value ?? 0
        return VStack(spacing: S(9)) { record("Longest session", DurationText.compact(longest)); record("Best day", DurationText.compact(bestDay)); record("Current streak", "\(streak) days"); record("Longest streak", "\(longestStreak) days"); record("Goal days", "\(completedGoalDays)"); record("Total XP", "\(xp) XP") }
    }

    private var badges: some View {
        let total = totalHours
        let earned: [ProgressBadge] = [
            .init(id: "first", title: "First session", requirement: "Complete your first session", unlocked: total > 0, progress: String(store.sessions.count) + " sessions"),
            .init(id: "ten", title: "10 hours", requirement: "Work 10 total hours", unlocked: total >= 10, progress: progressText(DurationText.compact(total * 3600), "10h")),
            .init(id: "fifty", title: "50 hours", requirement: "Work 50 total hours", unlocked: total >= 50, progress: progressText(DurationText.compact(total * 3600), "50h")),
            .init(id: "hundred", title: "100 hours", requirement: "Work 100 total hours", unlocked: total >= 100, progress: progressText(DurationText.compact(total * 3600), "100h")),
            .init(id: "quarter", title: "250 hours", requirement: "Work 250 total hours", unlocked: total >= 250, progress: progressText(DurationText.compact(total * 3600), "250h")),
            .init(id: "fivehundred", title: "500 hours", requirement: "Work 500 total hours", unlocked: total >= 500, progress: progressText(DurationText.compact(total * 3600), "500h")),
            .init(id: "sevenfifty", title: "750 hours", requirement: "Work 750 total hours", unlocked: total >= 750, progress: progressText(DurationText.compact(total * 3600), "750h")),
            .init(id: "thousand", title: "1,000 hours", requirement: "Work 1,000 total hours", unlocked: total >= 1_000, progress: progressText(DurationText.compact(total * 3600), "1,000h")),
            .init(id: "titan", title: "1,500 hours", requirement: "Work 1,500 total hours", unlocked: total >= 1_500, progress: progressText(DurationText.compact(total * 3600), "1,500h")),
            .init(id: "streak", title: "3-day streak", requirement: "Keep a 3-day streak", unlocked: streak >= 3, progress: progressText(String(streak), "3 days")),
            .init(id: "weekstreak", title: "7-day streak", requirement: "Keep a 7-day streak", unlocked: streak >= 7, progress: progressText(String(streak), "7 days")),
            .init(id: "monthstreak", title: "30-day streak", requirement: "Keep a 30-day streak", unlocked: streak >= 30, progress: progressText(String(streak), "30 days")),
            .init(id: "streak14", title: "14-day streak", requirement: "Reach a 14-day streak", unlocked: longestStreak >= 14, progress: progressText(String(longestStreak), "14 days")),
            .init(id: "streak60", title: "60-day streak", requirement: "Reach a 60-day streak", unlocked: longestStreak >= 60, progress: progressText(String(longestStreak), "60 days")),
            .init(id: "week", title: "7 sessions", requirement: "Log 7 sessions", unlocked: store.sessions.count >= 7, progress: progressText(String(store.sessions.count), "7 sessions")),
            .init(id: "sessions25", title: "25 sessions", requirement: "Log 25 sessions", unlocked: store.sessions.count >= 25, progress: progressText(String(store.sessions.count), "25 sessions")),
            .init(id: "marathon", title: "4-hour session", requirement: "Complete a 4-hour session", unlocked: longestSession >= 4 * 3600, progress: progressText(DurationText.compact(longestSession), "4h")),
            .init(id: "ultra", title: "8-hour session", requirement: "Complete an 8-hour session", unlocked: longestSession >= 8 * 3600, progress: progressText(DurationText.compact(longestSession), "8h")),
            .init(id: "xp", title: "10,000 XP", requirement: "Earn 10,000 XP", unlocked: xp >= 10_000, progress: progressText(String(xp), "10,000 XP")),
            .init(id: "goal", title: "Daily goal", requirement: "Complete a daily goal", unlocked: completedGoalDays >= 1, progress: String(completedGoalDays) + " goal days"),
            .init(id: "doublegoal", title: "Double daily goal", requirement: "Reach 2× a daily goal", unlocked: doubleGoalDays >= 1, progress: String(doubleGoalDays) + " double-goal days"),
            .init(id: "monthgoal", title: "Monthly goal", requirement: "Complete a monthly goal", unlocked: completedGoalMonths >= 1, progress: String(completedGoalMonths) + " goal months"),
            .init(id: "xp25", title: "25,000 XP", requirement: "Earn 25,000 XP", unlocked: xp >= 25_000, progress: progressText(String(xp), "25,000 XP")),
            .init(id: "active5", title: "5 active days", requirement: "Work on 5 different days", unlocked: activeDays >= 5, progress: progressText(String(activeDays), "5 active days")),
            .init(id: "active25", title: "25 active days", requirement: "Work on 25 different days", unlocked: activeDays >= 25, progress: progressText(String(activeDays), "25 active days")),
            .init(id: "active100", title: "100 active days", requirement: "Work on 100 different days", unlocked: activeDays >= 100, progress: progressText(String(activeDays), "100 active days")),
            .init(id: "earlybird", title: "Start 5 sessions before 08:00", requirement: "Start 5 sessions before 08:00", unlocked: earlyBirdSessions >= 5, progress: progressText(String(earlyBirdSessions), "5 early starts")),
            .init(id: "nightowl", title: "Start 5 sessions after 22:00", requirement: "Start 5 sessions after 22:00", unlocked: nightOwlSessions >= 5, progress: progressText(String(nightOwlSessions), "5 late starts")),
            .init(id: "weekend", title: "On 4 weekend days", requirement: "Work on 4 weekend days", unlocked: weekendDays >= 4, progress: progressText(String(weekendDays), "4 weekend days")),
            .init(id: "sessions50", title: "50 sessions", requirement: "Log 50 sessions", unlocked: store.sessions.count >= 50, progress: progressText(String(store.sessions.count), "50 sessions")),
            .init(id: "sessions100", title: "100 sessions", requirement: "Log 100 sessions", unlocked: store.sessions.count >= 100, progress: progressText(String(store.sessions.count), "100 sessions")),
            .init(id: "sessions200", title: "200 sessions", requirement: "Log 200 sessions", unlocked: store.sessions.count >= 200, progress: progressText(String(store.sessions.count), "200 sessions")),
            .init(id: "sessions500", title: "500 sessions", requirement: "Log 500 sessions", unlocked: store.sessions.count >= 500, progress: progressText(String(store.sessions.count), "500 sessions")),
            .init(id: "ultra12", title: "12-hour session", requirement: "Complete a 12-hour session", unlocked: longestSession >= 12 * 3600, progress: progressText(DurationText.compact(longestSession), "12h")),
            .init(id: "ultra15", title: "15-hour session", requirement: "Complete a 15-hour session", unlocked: longestSession >= 15 * 3600, progress: progressText(DurationText.compact(longestSession), "15h")),
            .init(id: "goal7", title: "7 daily goals", requirement: "Complete daily goals on 7 days", unlocked: completedGoalDays >= 7, progress: progressText(String(completedGoalDays), "7 goal days")),
            .init(id: "goal30", title: "30 daily goals", requirement: "Complete daily goals on 30 days", unlocked: completedGoalDays >= 30, progress: progressText(String(completedGoalDays), "30 goal days")),
            .init(id: "month3", title: "3 monthly goals", requirement: "Complete 3 monthly goals", unlocked: completedGoalMonths >= 3, progress: progressText(String(completedGoalMonths), "3 goal months")),
            .init(id: "month12", title: "12 monthly goals", requirement: "Complete 12 monthly goals", unlocked: completedGoalMonths >= 12, progress: progressText(String(completedGoalMonths), "12 goal months")),
            .init(id: "streak90", title: "90-day streak", requirement: "Reach a 90-day streak", unlocked: longestStreak >= 90, progress: progressText(String(longestStreak), "90 days")),
            .init(id: "streak180", title: "180-day streak", requirement: "Reach a 180-day streak", unlocked: longestStreak >= 180, progress: progressText(String(longestStreak), "180 days")),
            .init(id: "streak365", title: "365-day streak", requirement: "Reach a 365-day streak", unlocked: longestStreak >= 365, progress: progressText(String(longestStreak), "365 days")),
            .init(id: "active250", title: "250 active days", requirement: "Work on 250 different days", unlocked: activeDays >= 250, progress: progressText(String(activeDays), "250 active days")),
            .init(id: "active500", title: "500 active days", requirement: "Work on 500 different days", unlocked: activeDays >= 500, progress: progressText(String(activeDays), "500 active days")),
            .init(id: "xp50", title: "50,000 XP", requirement: "Earn 50,000 XP", unlocked: xp >= 50_000, progress: progressText(String(xp), "50,000 XP")),
            .init(id: "xp100", title: "100,000 XP", requirement: "Earn 100,000 XP", unlocked: xp >= 100_000, progress: progressText(String(xp), "100,000 XP"))
        ]
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: S(10)) {
            ForEach(earned) { badge in
                Button { selectedBadge = badge } label: {
                    VStack(spacing: S(7)) {
                    Image(systemName: badge.unlocked ? "checkmark" : "lock")
                        .font(.system(size: S(16), weight: .medium))
                        .foregroundStyle(badge.unlocked ? theme.accent : .secondary)
                    Text(badge.title).font(.system(size: S(10), weight: .bold))
                    Text(badge.unlocked ? "Unlocked • \(badge.requirement)" : badge.requirement)
                        .font(.system(size: S(10))).foregroundStyle(badge.unlocked ? theme.accent : .secondary)
                        .multilineTextAlignment(.center).lineLimit(nil).fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, minHeight: S(92)).padding(.vertical, S(8)).opacity(badge.unlocked ? 1 : 0.75)
                }
                .buttonStyle(.clockin(.secondary, size: .small, fullWidth: true))
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
            reportMetric("Active days", "\(activeDays)")
            reportMetric("Average session", DurationText.compact(sessionAverage))
            reportMetric("Best weekday", bestWeekday)
            reportMetric("Best start hour", bestHour)
            reportMetric("Average earnings / hour", store.currencyCode == "USD" ? hourlyEarning.money(code: store.currencyCode) : hourlyEarning.money(code: store.currencyCode))
            reportMetric("Last 30d trend", String(format: "%+.0f%%", trend * 100))
            Text("Reports are calculated from completed sessions and update after each clock-out.").font(.system(size: S(10))).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(S(10))
        }
    }

    private var weekly: some View {
        let cal = Calendar.current; let start = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: now)) ?? now
        let current = store.sessions.filter { $0.start >= start }.reduce(0) { $0 + $1.duration } + (store.running?.elapsed(at: now) ?? 0)
        let previousStart = cal.date(byAdding: .day, value: -13, to: cal.startOfDay(for: now)) ?? now
        let previous = store.sessions.filter { $0.start >= previousStart && $0.start < start }.reduce(0) { $0 + $1.duration }
        let delta = previous > 0 ? (current - previous) / previous : 1
        return VStack(spacing: S(12)) { reportMetric("This week", DurationText.compact(current)); reportMetric("Last week", DurationText.compact(previous)); reportMetric("Change", String(format: "%+.0f%%", delta * 100)); Text("Compares the last 7 days with the previous 7 days.").font(.system(size: S(11))).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(S(12)).background(card) }
    }

    private var goalETA: some View {
        let today = store.todayDuration(at: now) / 3600
        let remaining = max(0, dailyGoalHours - today)
        let recent = store.sessions.filter { $0.start >= now.addingTimeInterval(-7 * 86_400) }.reduce(0) { $0 + $1.duration } / 3600 / 7
        return VStack(alignment: .leading, spacing: S(6)) {
            Text("Estimated finish").font(ClockinFont.section).foregroundStyle(.secondary)
            if dailyGoalHours <= 0 && monthlyGoalHours <= 0 { Text("Set a daily or monthly goal in Settings.").font(.system(size: S(11))).foregroundStyle(.secondary) }
            else if dailyGoalHours > 0 && remaining <= 0 { Text("Daily goal reached").font(.system(size: S(11), weight: .semibold)).foregroundStyle(theme.accent) }
            else if let running = store.running, !running.isPaused, dailyGoalHours > 0 {
                Text("Today’s goal will be reached at \(now.addingTimeInterval(remaining * 3600).formatted(date: .omitted, time: .shortened)).").font(.system(size: S(11)))
            } else if dailyGoalHours > 0, recent > 0 {
                Text("At your 7-day average, today’s goal is about \(Int(ceil(remaining / recent))) day(s) away.").font(.system(size: S(11)))
            } else { Text("Start working to generate a live finish estimate.").font(.system(size: S(11))).foregroundStyle(.secondary) }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(S(12)).background(card)
    }
    private func stat(_ title: String, _ value: String) -> some View { VStack(spacing: S(4)) { Text(title).font(ClockinFont.section).foregroundStyle(.secondary); Text(value).font(.system(size: S(10), weight: .semibold, design: .monospaced)) }.frame(maxWidth: .infinity) }
    private func record(_ title: String, _ value: String) -> some View { HStack { Text(title).font(.system(size: S(11), weight: .semibold)); Spacer(); Text(value).font(.system(size: S(11), weight: .bold, design: .monospaced)) }.padding(S(13)).background(card) }
    private func reportMetric(_ title: String, _ value: String) -> some View { HStack { Text(title).font(ClockinFont.section).foregroundStyle(.secondary); Spacer(); Text(value).font(.system(size: S(16), weight: .bold, design: .rounded)) }.padding(S(14)).background(card) }
    private func progressText(_ current: String, _ target: String) -> String { current + " / " + target }
    private var card: some View {
        RoundedRectangle(cornerRadius: S(13), style: .continuous)
            .fill(theme.card)
            .overlay(RoundedRectangle(cornerRadius: S(13), style: .continuous).strokeBorder(theme.cardStroke))
    }
}

private struct BadgeDetailView: View {
    let badge: ProgressBadge
    let theme: ClockinPalette

    var body: some View {
        VStack(alignment: .leading, spacing: S(10)) {
            HStack(spacing: S(10)) {
                Image(systemName: badge.unlocked ? "checkmark" : "lock")
                    .font(.system(size: S(18), weight: .medium))
                    .foregroundStyle(badge.unlocked ? theme.accent : .secondary)
                VStack(alignment: .leading, spacing: S(2)) {
                    Text(badge.title).font(.system(size: S(14), weight: .black))
                    Text(badge.unlocked ? "Unlocked" : "Locked")
                        .font(.system(size: S(10), weight: .bold, design: .monospaced))
                        .foregroundStyle(badge.unlocked ? theme.accent : .secondary)
                }
            }
            Divider().opacity(0.2)
            Text(badge.unlocked ? "How you earned it" : "What's missing")
                .font(.system(size: S(10), weight: .bold)).foregroundStyle(.secondary)
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
        .clockinTextStyles()
        .preferredColorScheme(theme.colorScheme)
    }
}

private struct MascotView: View {
    @ObservedObject var store: ClockStore
    let now: Date
    let level: Int
    @AppStorage("Clockin.MascotEnabled") private var enabled = true
    var body: some View {
        Group {
            ClockinMascotStage().environmentObject(store)
        }
        .frame(width: S(72), height: S(72))
    }
}
