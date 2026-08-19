import AppKit
import SwiftUI
import UniformTypeIdentifiers

private enum ShareVisibility: String, CaseIterable, Identifiable {
    case publicStats = "Public"
    case privateStats = "Private"
    var id: String { rawValue }
}

private enum ShareExportMode: String, CaseIterable, Identifiable {
    case all = "All 3"
    case page = "Current page"
    var id: String { rawValue }
}

private struct ShareStatsSnapshot {
    let totalDuration: TimeInterval
    let earnings: Double
    let currencyCode: String
    let sessions: Int
    let activeDays: Int
    let currentStreak: Int
    let longestStreak: Int
    let bestDayDate: Date?
    let bestDayDuration: TimeInterval
    let bestWeekday: String
    let bestStartHour: String
    let goalDays: Int
    let doubleGoalDays: Int
    let monthlyGoals: Int
    let momentum: Int
    let level: Int
    let xp: Int
    let badges: Int
    let generatedAt: Date
}

struct ShareStatsView: View {
    @AppStorage(UIScale.key) private var uiScaleObserver = 1.0
    @EnvironmentObject private var store: ClockStore
    @EnvironmentObject private var exchangeRates: ExchangeRateStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("Clockin.Theme") private var themeRaw = ClockinThemeChoice.carbon.rawValue
    @AppStorage("Clockin.GoalDailyHours") private var dailyGoalHours = 0.0
    @AppStorage("Clockin.GoalMonthlyHours") private var monthlyGoalHours = 0.0
    @State private var visibility: ShareVisibility = .publicStats
    @State private var exportMode: ShareExportMode = .all
    @State private var page = 0
    @State private var now = Date()
    @State private var status: String?

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private var theme: ClockinPalette { ClockinThemeChoice.selected(themeRaw).palette }

    private var dailyDurations: [Date: TimeInterval] {
        let calendar = Calendar.current
        var values: [Date: TimeInterval] = [:]
        for session in store.sessions { values[calendar.startOfDay(for: session.start), default: 0] += session.duration }
        if let running = store.running { values[calendar.startOfDay(for: running.start), default: 0] += running.elapsed(at: now) }
        return values
    }

    private var bonusXP: Int {
        let daily = dailyGoalHours > 0 ? dailyDurations.values.filter { $0 >= dailyGoalHours * 3600 }.count * 100 : 0
        let double = dailyGoalHours > 0 ? dailyDurations.values.filter { $0 >= dailyGoalHours * 7200 }.count * 250 : 0
        let calendar = Calendar.current
        let monthly = monthlyGoalHours > 0
            ? Dictionary(grouping: dailyDurations) { calendar.dateInterval(of: .month, for: $0.key)?.start ?? $0.key }
                .values.map { $0.reduce(0) { $0 + $1.value } }.filter { $0 >= monthlyGoalHours * 3600 }.count * 500
            : 0
        let streak = longestStreak
        let streakXP = [(3, 100), (7, 250), (14, 500), (30, 1_000), (60, 2_000)].filter { streak >= $0.0 }.reduce(0) { $0 + $1.1 }
        return daily + double + monthly + streakXP
    }

    private var longestStreak: Int {
        let calendar = Calendar.current
        let days = dailyDurations.keys.sorted()
        guard !days.isEmpty else { return 0 }
        var best = 1
        var current = 1
        for pair in zip(days, days.dropFirst()) {
            if calendar.dateComponents([.day], from: pair.0, to: pair.1).day == 1 { current += 1; best = max(best, current) } else { current = 1 }
        }
        return best
    }

    private var goalDays: Int { dailyGoalHours > 0 ? dailyDurations.values.filter { $0 >= dailyGoalHours * 3600 }.count : 0 }
    private var doubleGoalDays: Int { dailyGoalHours > 0 ? dailyDurations.values.filter { $0 >= dailyGoalHours * 7200 }.count : 0 }
    private var monthlyGoals: Int {
        guard monthlyGoalHours > 0 else { return 0 }
        let calendar = Calendar.current
        return Dictionary(grouping: dailyDurations) { calendar.dateInterval(of: .month, for: $0.key)?.start ?? $0.key }
            .values.map { $0.reduce(0) { $0 + $1.value } }.filter { $0 >= monthlyGoalHours * 3600 }.count
    }

    private var reportStats: (bestDay: (Date, TimeInterval)?, weekday: String, hour: String, momentum: Int) {
        let calendar = Calendar.current
        let bestDay = dailyDurations.max { $0.value < $1.value }.map { ($0.key, $0.value) }
        let weekdays = Dictionary(grouping: store.sessions) { calendar.component(.weekday, from: $0.start) }
        let weekday = weekdays.max { left, right in
            left.value.reduce(0) { $0 + $1.duration } < right.value.reduce(0) { $0 + $1.duration }
        }.map { calendar.weekdaySymbols[$0.key - 1] } ?? "—"
        let hours = Dictionary(grouping: store.sessions) { calendar.component(.hour, from: $0.start) }
        let hour = hours.max { left, right in
            left.value.reduce(0) { $0 + $1.duration } < right.value.reduce(0) { $0 + $1.duration }
        }.map { String(format: "%02d:00", $0.key) } ?? "—"
        let recentCutoff = now.addingTimeInterval(-30 * 86_400)
        let recent = store.sessions.filter { $0.start >= recentCutoff }.reduce(0) { $0 + $1.duration }
        let prior = store.sessions.filter { $0.start >= now.addingTimeInterval(-60 * 86_400) && $0.start < recentCutoff }.reduce(0) { $0 + $1.duration }
        let momentum = prior > 0 ? Int(((recent - prior) / prior * 100).rounded()) : (recent > 0 ? 100 : 0)
        return (bestDay, weekday, hour, momentum)
    }

    private var snapshot: ShareStatsSnapshot {
        let totalDuration = store.allDuration(at: now)
        let totalHours = totalDuration / 3600
        let xp = Int(totalHours * 100) + bonusXP
        let report = reportStats
        let dates = Set(store.sessions.map { Calendar.current.startOfDay(for: $0.start) } + (store.running.map { [Calendar.current.startOfDay(for: $0.start)] } ?? []))
        let badges = [
            totalHours > 0, totalHours >= 10, totalHours >= 50, totalHours >= 100, totalHours >= 250,
            currentStreak >= 3, currentStreak >= 7, currentStreak >= 30,
            store.sessions.count >= 7, store.sessions.count >= 25,
            (store.sessions.map(\.duration).max() ?? 0) >= 4 * 3600,
            (store.sessions.map(\.duration).max() ?? 0) >= 8 * 3600,
            xp >= 10_000
        ].filter { $0 }.count
        return ShareStatsSnapshot(
            totalDuration: totalDuration,
            earnings: store.allEarnings(at: now),
            currencyCode: store.currencyCode,
            sessions: store.sessions.count,
            activeDays: dates.count,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            bestDayDate: report.bestDay?.0,
            bestDayDuration: report.bestDay?.1 ?? 0,
            bestWeekday: report.weekday,
            bestStartHour: report.hour,
            goalDays: goalDays,
            doubleGoalDays: doubleGoalDays,
            monthlyGoals: monthlyGoals,
            momentum: report.momentum,
            level: max(1, xp / 500 + 1),
            xp: xp,
            badges: badges,
            generatedAt: now
        )
    }

    var body: some View {
        VStack(spacing: S(0)) {
            HStack {
                VStack(alignment: .leading, spacing: S(3)) {
                    Text("SHARE YOUR STATS").font(.system(size: S(13), weight: .black, design: theme.fontDesign)).tracking(S(1.2))
                    Text("A Clockin rewind card for your focus journey")
                        .font(.system(size: S(9))).foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: { dismiss() }) { Image(systemName: "xmark").frame(width: S(26), height: S(26)) }.buttonStyle(.plain)
            }
            .padding(.horizontal, S(15)).frame(height: S(54))
            .overlay(alignment: .bottom) { Divider().opacity(0.25) }

            Picker("Privacy", selection: $visibility) {
                ForEach(ShareVisibility.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, S(16)).padding(.top, S(12))

            HStack(spacing: S(12)) {
                Button { page = max(0, page - 1) } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(.plain).disabled(page == 0)
                Text("PAGE \(page + 1) / 3 • \(["OVERVIEW", "RHYTHM", "MILESTONES"][page])")
                    .font(.system(size: S(9), weight: .bold, design: .monospaced)).foregroundStyle(theme.accent)
                Button { page = min(2, page + 1) } label: { Image(systemName: "chevron.right") }
                    .buttonStyle(.plain).disabled(page == 2)
            }
            .padding(.top, S(9))

            Picker("Export", selection: $exportMode) {
                ForEach(ShareExportMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, S(16))
            .padding(.top, S(9))

            ScrollView {
                exportPreview
                    .padding(.vertical, S(14))
            }

            HStack(spacing: S(9)) {
                Button { copyPNG() } label: { Label("Copy", systemImage: "doc.on.doc") }
                    .buttonStyle(.bordered)
                Button { savePNG() } label: { Label("Save PNG", systemImage: "arrow.down.to.line") }
                    .buttonStyle(.bordered)
                Button { sharePNG() } label: { Label("Share", systemImage: "square.and.arrow.up") }
                    .buttonStyle(RewindShareButtonStyle(background: theme.accent, foreground: theme.background))
            }
            .padding(.horizontal, S(16)).padding(.bottom, S(8))
            if let status { Text(status).font(.system(size: S(9))).foregroundStyle(.secondary).padding(.bottom, S(7)) }
        }
        // Sheet olarak sunuluyor: kendi olcusunu bildirmeli.
        .frame(width: S(UIScale.base.width), height: S(UIScale.base.height))
        .background(theme.background)
        .fontDesign(theme.fontDesign)
        .preferredColorScheme(theme.colorScheme)
        .onReceive(timer) { now = $0 }
    }

    @ViewBuilder
    private var exportPreview: some View {
        if exportMode == .all {
            ShareStatsLongCard(snapshot: snapshot, visibility: visibility, theme: theme)
        } else {
            ShareStatsPageCard(snapshot: snapshot, visibility: visibility, theme: theme, page: page)
        }
    }

    private var currentStreak: Int {
        let calendar = Calendar.current
        let days = Set(store.sessions.map { calendar.startOfDay(for: $0.start) } + (store.running.map { [calendar.startOfDay(for: $0.start)] } ?? []))
        var cursor = calendar.startOfDay(for: now)
        if !days.contains(cursor) { cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor }
        var count = 0
        while days.contains(cursor) {
            count += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        return count
    }

    private func renderPNG() -> URL? {
        let renderer: ImageRenderer<AnyView>
        if exportMode == .all {
            renderer = ImageRenderer(content: AnyView(ShareStatsLongCard(snapshot: snapshot, visibility: visibility, theme: theme)))
        } else {
            renderer = ImageRenderer(content: AnyView(ShareStatsPageCard(snapshot: snapshot, visibility: visibility, theme: theme, page: page)))
        }
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            status = "Could not create image."
            return nil
        }
        let label = visibility == .publicStats ? "public" : "private"
        let suffix = exportMode == .all ? "all" : "page-\(page + 1)"
        let url = FileManager.default.temporaryDirectory.appending(path: "clockin-stats-\(label)-\(suffix)-\(Int(now.timeIntervalSince1970)).png")
        do {
            try png.write(to: url, options: .atomic)
            return url
        } catch {
            status = "Could not save image: \(error.localizedDescription)"
            return nil
        }
    }

    private func savePNG() {
        guard let source = renderPNG() else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = source.lastPathComponent
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        do {
            try FileManager.default.copyItem(at: source, to: destination)
            status = "PNG saved."
        } catch {
            status = "Could not save image: \(error.localizedDescription)"
        }
    }

    private func sharePNG() {
        guard let url = renderPNG(), let contentView = NSApp.keyWindow?.contentView else { return }
        let picker = NSSharingServicePicker(items: [url])
        picker.show(relativeTo: NSRect(x: contentView.bounds.midX, y: contentView.bounds.minY + 12, width: S(1), height: S(1)), of: contentView, preferredEdge: .minY)
    }

    private func copyPNG() {
        guard let url = renderPNG(), let image = NSImage(contentsOf: url) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
        status = "PNG copied to clipboard."
    }
}

private struct RewindShareButtonStyle: ButtonStyle {
    let background: Color
    let foreground: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: S(11), weight: .bold))
            .padding(.horizontal, S(12))
            .padding(.vertical, S(7))
            .foregroundStyle(foreground)
            .background(background.opacity(configuration.isPressed ? 0.72 : 1), in: RoundedRectangle(cornerRadius: S(8)))
            .overlay(RoundedRectangle(cornerRadius: S(8)).stroke(.white.opacity(0.18)))
    }
}

private struct ShareStatsCard: View {
    let snapshot: ShareStatsSnapshot
    let visibility: ShareVisibility
    let theme: ClockinPalette

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [theme.background, theme.background.opacity(0.88), theme.accent.opacity(0.34)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(theme.accent.opacity(0.18)).frame(width: S(250), height: S(250)).blur(radius: 3).offset(x: 220, y: -110)
            Circle().fill(.white.opacity(0.07)).frame(width: S(180), height: S(180)).blur(radius: 4).offset(x: -100, y: 350)
            VStack(alignment: .leading, spacing: S(0)) {
                HStack {
                    Text("CLOCKIN").font(.system(size: S(13), weight: .black, design: theme.fontDesign)).tracking(S(2.4))
                    Spacer()
                    Text("STATS REWIND").font(.system(size: S(9), weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.7)).tracking(S(1.1))
                }
                Spacer().frame(height: S(44))
                Text(visibility == .publicStats ? "YOUR FOCUS\nIN NUMBERS" : "YOUR FOCUS\nSTAYS PRIVATE")
                    .font(.system(size: S(30), weight: .black, design: theme.fontDesign))
                    .tracking(-0.8)
                    .foregroundStyle(.white)
                Text(snapshot.generatedAt.formatted(.dateTime.month(.wide).day().year()))
                    .font(.system(size: S(10), weight: .semibold, design: .monospaced)).foregroundStyle(.white.opacity(0.65))
                    .padding(.top, S(8))
                Spacer().frame(height: S(38))
                if visibility == .publicStats { publicStats } else { privateStats }
                Spacer()
                HStack {
                    Text("LEVEL \(snapshot.level)").font(.system(size: S(11), weight: .black, design: .monospaced))
                    Spacer()
                    Text("\(snapshot.badges) BADGES").font(.system(size: S(10), weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.75))
                }
                .padding(.top, S(18))
            }
            .padding(S(30))
        }
        .frame(width: S(350), height: S(500))
        .clipShape(RoundedRectangle(cornerRadius: S(26), style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: S(26), style: .continuous).stroke(.white.opacity(0.16)))
        .shadow(color: theme.accent.opacity(0.22), radius: 18, y: 8)
    }

    private var publicStats: some View {
        VStack(alignment: .leading, spacing: S(17)) {
            stat("TIME INVESTED", DurationText.compact(snapshot.totalDuration), accent: true)
            stat("EARNED", snapshot.earnings.money(code: snapshot.currencyCode), accent: false)
            HStack(spacing: S(24)) {
                mini("SESSIONS", "\(snapshot.sessions)")
                mini("ACTIVE DAYS", "\(snapshot.activeDays)")
                mini("STREAK", "\(snapshot.currentStreak)d")
            }
        }
    }

    private var privateStats: some View {
        VStack(alignment: .leading, spacing: S(17)) {
            HStack(spacing: S(12)) {
                Image(systemName: "lock.fill").font(.system(size: S(22))).foregroundStyle(theme.accent)
                Text("TIME & EARNINGS HIDDEN").font(.system(size: S(12), weight: .black, design: .monospaced))
            }
            Text("A private version of your progress card. Share the motivation without revealing your hours or money.")
                .font(.system(size: S(11), weight: .medium)).foregroundStyle(.white.opacity(0.7)).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: S(24)) {
                mini("STREAK", "\(snapshot.currentStreak)d")
                mini("BADGES", "\(snapshot.badges)")
                mini("XP", "\(snapshot.xp)")
            }
        }
    }

    private func stat(_ label: String, _ value: String, accent: Bool) -> some View {
        VStack(alignment: .leading, spacing: S(4)) {
            Text(label).font(.system(size: S(9), weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.62)).tracking(S(1))
            Text(value).font(.system(size: accent ? 28 : 24, weight: .black, design: theme.fontDesign)).foregroundStyle(accent ? theme.accent : .white)
        }
    }

    private func mini(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: S(4)) {
            Text(label).font(.system(size: S(8), weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.55))
            Text(value).font(.system(size: S(16), weight: .black, design: .monospaced)).foregroundStyle(.white)
        }
    }
}

private struct ShareStatsRewindCard: View {
    let snapshot: ShareStatsSnapshot
    let visibility: ShareVisibility
    let theme: ClockinPalette

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [theme.background, theme.background.opacity(0.88), theme.accent.opacity(0.34)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(theme.accent.opacity(0.18)).frame(width: S(250), height: S(250)).blur(radius: 3).offset(x: 220, y: -110)
            Circle().fill(.white.opacity(0.07)).frame(width: S(180), height: S(180)).blur(radius: 4).offset(x: -100, y: 500)
            VStack(spacing: S(12)) {
                hero
                rhythm
                milestones
            }
            .padding(S(16))
        }
        .frame(width: S(350))
        .clipShape(RoundedRectangle(cornerRadius: S(26), style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: S(26), style: .continuous).stroke(.white.opacity(0.16)))
        .shadow(color: theme.accent.opacity(0.22), radius: 18, y: 8)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: S(0)) {
            HStack {
                Text("CLOCKIN").font(.system(size: S(13), weight: .black, design: theme.fontDesign)).tracking(S(2.4))
                Spacer()
                Text("STATS REWIND").font(.system(size: S(9), weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.7)).tracking(S(1.1))
            }
            Spacer().frame(height: S(38))
            Text(visibility == .publicStats ? "YOUR FOCUS\nIN NUMBERS" : "YOUR FOCUS\nJOURNEY")
                .font(.system(size: S(29), weight: .black, design: theme.fontDesign)).tracking(-0.8).foregroundStyle(.white)
            Text(snapshot.generatedAt.formatted(.dateTime.month(.wide).day().year()))
                .font(.system(size: S(10), weight: .semibold, design: .monospaced)).foregroundStyle(.white.opacity(0.65)).padding(.top, S(8))
            Spacer().frame(height: S(30))
            if visibility == .publicStats { publicHero } else { privateHero }
            Spacer()
            HStack {
                Text("LEVEL \(snapshot.level)").font(.system(size: S(11), weight: .black, design: .monospaced))
                Spacer()
                Text("\(snapshot.badges) BADGES").font(.system(size: S(10), weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.75))
            }
        }
        .padding(S(18))
        .frame(height: S(500), alignment: .top)
        .background(.black.opacity(0.15), in: RoundedRectangle(cornerRadius: S(21), style: .continuous))
    }

    private var publicHero: some View {
        VStack(alignment: .leading, spacing: S(16)) {
            stat("TIME INVESTED", DurationText.compact(snapshot.totalDuration), accent: true)
            stat("EARNED", snapshot.earnings.money(code: snapshot.currencyCode), accent: false)
            HStack(spacing: S(22)) {
                mini("SESSIONS", "\(snapshot.sessions)")
                mini("ACTIVE DAYS", "\(snapshot.activeDays)")
                mini("STREAK", "\(snapshot.currentStreak)d")
            }
        }
    }

    private var privateHero: some View {
        VStack(alignment: .leading, spacing: S(16)) {
            HStack(spacing: S(12)) {
                Image(systemName: "sparkles").font(.system(size: S(22))).foregroundStyle(theme.accent)
                Text("FOCUS JOURNEY").font(.system(size: S(12), weight: .black, design: .monospaced))
            }
            Text("A private rewind of your momentum, milestones and rhythm.")
                .font(.system(size: S(11), weight: .medium)).foregroundStyle(.white.opacity(0.7)).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: S(22)) {
                mini("STREAK", "\(snapshot.currentStreak)d")
                mini("BADGES", "\(snapshot.badges)")
                mini("XP", "\(snapshot.xp)")
            }
        }
    }

    private var rhythm: some View {
        VStack(alignment: .leading, spacing: S(12)) {
            Text("RHYTHM REPORT").font(.system(size: S(9), weight: .black, design: .monospaced)).foregroundStyle(.white.opacity(0.65)).tracking(S(1.2))
            HStack(spacing: S(7)) {
                reportMetric("BEST DAY", bestDayText)
                reportMetric("BEST STREAK", "\(snapshot.longestStreak)d")
                reportMetric("ACTIVE DAYS", "\(snapshot.activeDays)")
            }
            HStack(spacing: S(7)) {
                reportMetric("BEST WEEKDAY", snapshot.bestWeekday)
                reportMetric("POWER HOUR", snapshot.bestStartHour)
            }
        }
        .padding(S(14))
        .background(.black.opacity(0.15), in: RoundedRectangle(cornerRadius: S(21), style: .continuous))
    }

    private var milestones: some View {
        VStack(alignment: .leading, spacing: S(12)) {
            Text("MILESTONES & MOMENTUM").font(.system(size: S(9), weight: .black, design: .monospaced)).foregroundStyle(.white.opacity(0.65)).tracking(S(1.2))
            HStack(spacing: S(7)) {
                reportMetric("LEVEL", "\(snapshot.level)")
                reportMetric("XP", "\(snapshot.xp)")
                reportMetric("BADGES", "\(snapshot.badges)")
            }
            HStack(spacing: S(5)) {
                reportMetric("GOAL DAYS", "\(snapshot.goalDays)")
                reportMetric("2× DAYS", "\(snapshot.doubleGoalDays)")
                reportMetric("MONTH GOALS", "\(snapshot.monthlyGoals)")
                reportMetric("MOMENTUM", "\(snapshot.momentum >= 0 ? "+" : "")\(snapshot.momentum)%")
            }
        }
        .padding(S(14))
        .background(.black.opacity(0.15), in: RoundedRectangle(cornerRadius: S(21), style: .continuous))
    }

    private var bestDayText: String {
        guard let date = snapshot.bestDayDate else { return "—" }
        let dateText = date.formatted(.dateTime.month(.abbreviated).day())
        return visibility == .publicStats ? "\(dateText) • \(DurationText.compact(snapshot.bestDayDuration))" : dateText
    }

    private func reportMetric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: S(4)) {
            Text(label).font(.system(size: S(7), weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.5))
            Text(value).font(.system(size: S(11), weight: .black, design: .monospaced)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stat(_ label: String, _ value: String, accent: Bool) -> some View {
        VStack(alignment: .leading, spacing: S(4)) {
            Text(label).font(.system(size: S(9), weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.62)).tracking(S(1))
            Text(value).font(.system(size: accent ? 28 : 24, weight: .black, design: theme.fontDesign)).foregroundStyle(accent ? theme.accent : .white)
        }
    }

    private func mini(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: S(4)) {
            Text(label).font(.system(size: S(8), weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.55))
            Text(value).font(.system(size: S(16), weight: .black, design: .monospaced)).foregroundStyle(.white)
        }
    }
}

private struct ShareStatsPageCard: View {
    let snapshot: ShareStatsSnapshot
    let visibility: ShareVisibility
    let theme: ClockinPalette
    let page: Int

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [theme.background, theme.background.opacity(0.88), theme.accent.opacity(0.34)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(theme.accent.opacity(0.18)).frame(width: S(240), height: S(240)).blur(radius: 4).offset(x: 230, y: -90)
            Circle().fill(.white.opacity(0.07)).frame(width: S(170), height: S(170)).blur(radius: 4).offset(x: -90, y: 390)
            VStack(alignment: .leading, spacing: S(0)) {
                HStack {
                    Text("CLOCKIN").font(.system(size: S(13), weight: .black, design: theme.fontDesign)).tracking(S(2.4))
                    Spacer()
                    Text("\(String(format: "%02d", page + 1)) / 03").font(.system(size: S(9), weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.65))
                }
                Spacer().frame(height: S(42))
                Text(pageTitle).font(.system(size: S(30), weight: .black, design: theme.fontDesign)).tracking(-0.8).foregroundStyle(.white)
                Text(snapshot.generatedAt.formatted(.dateTime.month(.wide).day().year()))
                    .font(.system(size: S(10), weight: .semibold, design: .monospaced)).foregroundStyle(.white.opacity(0.65)).padding(.top, S(8))
                Spacer().frame(height: S(36))
                if page == 0 { overview } else if page == 1 { rhythm } else { milestones }
                Spacer()
                HStack {
                    Text("CLOCKIN • STATS REWIND").font(.system(size: S(9), weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.55))
                    Spacer()
                    Text(visibility == .publicStats ? "PUBLIC" : "PRIVATE").font(.system(size: S(8), weight: .black, design: .monospaced)).foregroundStyle(theme.accent)
                }
            }
            .padding(S(28))
        }
        .frame(width: S(350), height: S(500))
        .clipShape(RoundedRectangle(cornerRadius: S(26), style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: S(26), style: .continuous).stroke(.white.opacity(0.16)))
        .shadow(color: theme.accent.opacity(0.22), radius: 18, y: 8)
    }

    private var pageTitle: String {
        switch page {
        case 0: return visibility == .publicStats ? "FOCUS\nIN NUMBERS" : "FOCUS\nJOURNEY"
        case 1: return "RHYTHM\nREPORT"
        default: return "MILESTONES\n& MOMENTUM"
        }
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: S(18)) {
            if visibility == .publicStats {
                stat("TIME INVESTED", DurationText.compact(snapshot.totalDuration), accent: true)
                stat("EARNED", snapshot.earnings.money(code: snapshot.currencyCode), accent: false)
                HStack(spacing: S(23)) { mini("SESSIONS", "\(snapshot.sessions)"); mini("ACTIVE DAYS", "\(snapshot.activeDays)"); mini("STREAK", "\(snapshot.currentStreak)d") }
            } else {
                HStack(spacing: S(12)) { Image(systemName: "sparkles").font(.system(size: S(23))).foregroundStyle(theme.accent); Text("FOCUS JOURNEY").font(.system(size: S(13), weight: .black, design: .monospaced)) }
                Text("Momentum, milestones and rhythm — ready to share.").font(.system(size: S(12), weight: .medium)).foregroundStyle(.white.opacity(0.7)).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: S(23)) { mini("STREAK", "\(snapshot.currentStreak)d"); mini("BADGES", "\(snapshot.badges)"); mini("XP", "\(snapshot.xp)") }
            }
        }
    }

    private var rhythm: some View {
        VStack(alignment: .leading, spacing: S(18)) {
            metric("BEST DAY", bestDayText)
            metric("BEST STREAK", "\(snapshot.longestStreak) days")
            metric("ACTIVE DAYS", "\(snapshot.activeDays)")
            Divider().opacity(0.18)
            metric("BEST WEEKDAY", snapshot.bestWeekday)
            metric("POWER HOUR", snapshot.bestStartHour)
            metric("SESSIONS", "\(snapshot.sessions)")
        }
    }

    private var milestones: some View {
        VStack(alignment: .leading, spacing: S(18)) {
            metric("LEVEL", "\(snapshot.level)")
            metric("TOTAL XP", "\(snapshot.xp)")
            metric("BADGES UNLOCKED", "\(snapshot.badges)")
            Divider().opacity(0.18)
            metric("GOAL DAYS", "\(snapshot.goalDays)")
            metric("2× GOAL DAYS", "\(snapshot.doubleGoalDays)")
            metric("MONTH GOALS", "\(snapshot.monthlyGoals)")
            metric("MOMENTUM", "\(snapshot.momentum >= 0 ? "+" : "")\(snapshot.momentum)%")
        }
    }

    private var bestDayText: String {
        guard let date = snapshot.bestDayDate else { return "—" }
        let value = date.formatted(.dateTime.month(.abbreviated).day())
        return visibility == .publicStats ? "\(value) • \(DurationText.compact(snapshot.bestDayDuration))" : value
    }

    private func stat(_ label: String, _ value: String, accent: Bool) -> some View {
        VStack(alignment: .leading, spacing: S(4)) {
            Text(label).font(.system(size: S(9), weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.6)).tracking(S(1))
            Text(value).font(.system(size: accent ? 28 : 24, weight: .black, design: theme.fontDesign)).foregroundStyle(accent ? theme.accent : .white)
        }
    }

    private func metric(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(.system(size: S(9), weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.58)).tracking(S(0.8))
            Spacer()
            Text(value).font(.system(size: S(17), weight: .black, design: .monospaced)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.65)
        }
    }

    private func mini(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: S(4)) {
            Text(label).font(.system(size: S(8), weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.55))
            Text(value).font(.system(size: S(16), weight: .black, design: .monospaced)).foregroundStyle(.white)
        }
    }
}

private struct ShareStatsLongCard: View {
    let snapshot: ShareStatsSnapshot
    let visibility: ShareVisibility
    let theme: ClockinPalette

    var body: some View {
        VStack(spacing: S(12)) {
            ShareStatsPageCard(snapshot: snapshot, visibility: visibility, theme: theme, page: 0)
            ShareStatsPageCard(snapshot: snapshot, visibility: visibility, theme: theme, page: 1)
            ShareStatsPageCard(snapshot: snapshot, visibility: visibility, theme: theme, page: 2)
        }
        .padding(S(12))
        .background(theme.background)
        .frame(width: S(374))
    }
}
