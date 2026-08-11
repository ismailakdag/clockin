import AppKit
import SwiftUI
import UniformTypeIdentifiers

private enum ShareVisibility: String, CaseIterable, Identifiable {
    case publicStats = "Public"
    case privateStats = "Private"
    var id: String { rawValue }
}

private struct ShareStatsSnapshot {
    let totalDuration: TimeInterval
    let earnings: Double
    let currencyCode: String
    let sessions: Int
    let activeDays: Int
    let currentStreak: Int
    let level: Int
    let xp: Int
    let badges: Int
    let generatedAt: Date
}

struct ShareStatsView: View {
    @EnvironmentObject private var store: ClockStore
    @EnvironmentObject private var exchangeRates: ExchangeRateStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("Clockin.Theme") private var themeRaw = ClockinThemeChoice.carbon.rawValue
    @AppStorage("Clockin.GoalDailyHours") private var dailyGoalHours = 0.0
    @AppStorage("Clockin.GoalMonthlyHours") private var monthlyGoalHours = 0.0
    @State private var visibility: ShareVisibility = .publicStats
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

    private var snapshot: ShareStatsSnapshot {
        let totalDuration = store.allDuration(at: now)
        let totalHours = totalDuration / 3600
        let xp = Int(totalHours * 100) + bonusXP
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
            level: max(1, xp / 500 + 1),
            xp: xp,
            badges: badges,
            generatedAt: now
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("SHARE YOUR STATS").font(.system(size: 13, weight: .black, design: theme.fontDesign)).tracking(1.2)
                    Text("A Clockin rewind card for your focus journey")
                        .font(.system(size: 9)).foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: { dismiss() }) { Image(systemName: "xmark").frame(width: 26, height: 26) }.buttonStyle(.plain)
            }
            .padding(.horizontal, 15).frame(height: 54)
            .overlay(alignment: .bottom) { Divider().opacity(0.25) }

            Picker("Privacy", selection: $visibility) {
                ForEach(ShareVisibility.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16).padding(.top, 12)

            ScrollView {
                ShareStatsCard(snapshot: snapshot, visibility: visibility, theme: theme)
                    .padding(.vertical, 14)
            }

            HStack(spacing: 9) {
                Button { savePNG() } label: { Label("Save PNG", systemImage: "arrow.down.to.line") }
                    .buttonStyle(.bordered)
                Button { sharePNG() } label: { Label("Share", systemImage: "square.and.arrow.up") }
                    .buttonStyle(.borderedProminent).tint(theme.accent).foregroundStyle(.black)
            }
            .padding(.horizontal, 16).padding(.bottom, 8)
            if let status { Text(status).font(.system(size: 9)).foregroundStyle(.secondary).padding(.bottom, 7) }
        }
        .frame(width: 390, height: 650)
        .background(theme.background)
        .fontDesign(theme.fontDesign)
        .preferredColorScheme(.dark)
        .onReceive(timer) { now = $0 }
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
        let renderer = ImageRenderer(content: ShareStatsCard(snapshot: snapshot, visibility: visibility, theme: theme))
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            status = "Could not create image."
            return nil
        }
        let label = visibility == .publicStats ? "public" : "private"
        let url = FileManager.default.temporaryDirectory.appending(path: "clockin-stats-\(label)-\(Int(now.timeIntervalSince1970)).png")
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
        picker.show(relativeTo: NSRect(x: contentView.bounds.midX, y: contentView.bounds.minY + 12, width: 1, height: 1), of: contentView, preferredEdge: .minY)
    }
}

private struct ShareStatsCard: View {
    let snapshot: ShareStatsSnapshot
    let visibility: ShareVisibility
    let theme: ClockinPalette

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [theme.background, theme.background.opacity(0.88), theme.accent.opacity(0.34)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(theme.accent.opacity(0.18)).frame(width: 250, height: 250).blur(radius: 3).offset(x: 220, y: -110)
            Circle().fill(.white.opacity(0.07)).frame(width: 180, height: 180).blur(radius: 4).offset(x: -100, y: 350)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("CLOCKIN").font(.system(size: 13, weight: .black, design: theme.fontDesign)).tracking(2.4)
                    Spacer()
                    Text("STATS REWIND").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.7)).tracking(1.1)
                }
                Spacer().frame(height: 44)
                Text(visibility == .publicStats ? "YOUR FOCUS\nIN NUMBERS" : "YOUR FOCUS\nSTAYS PRIVATE")
                    .font(.system(size: 30, weight: .black, design: theme.fontDesign))
                    .tracking(-0.8)
                    .foregroundStyle(.white)
                Text(snapshot.generatedAt.formatted(.dateTime.month(.wide).day().year()))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(.white.opacity(0.65))
                    .padding(.top, 8)
                Spacer().frame(height: 38)
                if visibility == .publicStats { publicStats } else { privateStats }
                Spacer()
                HStack {
                    Text("LEVEL \(snapshot.level)").font(.system(size: 11, weight: .black, design: .monospaced))
                    Spacer()
                    Text("\(snapshot.badges) BADGES").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.75))
                }
                .padding(.top, 18)
            }
            .padding(30)
        }
        .frame(width: 350, height: 500)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(.white.opacity(0.16)))
        .shadow(color: theme.accent.opacity(0.22), radius: 18, y: 8)
    }

    private var publicStats: some View {
        VStack(alignment: .leading, spacing: 17) {
            stat("TIME INVESTED", DurationText.compact(snapshot.totalDuration), accent: true)
            stat("EARNED", snapshot.earnings.money(code: snapshot.currencyCode), accent: false)
            HStack(spacing: 24) {
                mini("SESSIONS", "\(snapshot.sessions)")
                mini("ACTIVE DAYS", "\(snapshot.activeDays)")
                mini("STREAK", "\(snapshot.currentStreak)d")
            }
        }
    }

    private var privateStats: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack(spacing: 12) {
                Image(systemName: "lock.fill").font(.system(size: 22)).foregroundStyle(theme.accent)
                Text("TIME & EARNINGS HIDDEN").font(.system(size: 12, weight: .black, design: .monospaced))
            }
            Text("A private version of your progress card. Share the motivation without revealing your hours or money.")
                .font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.7)).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 24) {
                mini("STREAK", "\(snapshot.currentStreak)d")
                mini("BADGES", "\(snapshot.badges)")
                mini("XP", "\(snapshot.xp)")
            }
        }
    }

    private func stat(_ label: String, _ value: String, accent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.62)).tracking(1)
            Text(value).font(.system(size: accent ? 28 : 24, weight: .black, design: theme.fontDesign)).foregroundStyle(accent ? theme.accent : .white)
        }
    }

    private func mini(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.55))
            Text(value).font(.system(size: 16, weight: .black, design: .monospaced)).foregroundStyle(.white)
        }
    }
}
