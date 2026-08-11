import SwiftUI

struct HeatmapView: View {
    private struct DayStats {
        var duration: TimeInterval = 0
        var earnings: Double = 0
    }

    @EnvironmentObject private var store: ClockStore
    @EnvironmentObject private var exchangeRates: ExchangeRateStore
    @AppStorage("Clockin.Theme") private var themeRaw = ClockinThemeChoice.carbon.rawValue
    @State private var now = Date()
    @State private var hoveredDate: Date?
    @State private var cachedStats: [Date: DayStats] = [:]
    let onBack: () -> Void

    private let calendar: Calendar = {
        var value = Calendar.autoupdatingCurrent
        value.firstWeekday = 2
        return value
    }()
    private let timer = Timer.publish(every: 20, on: .main, in: .common).autoconnect()
    private var theme: ClockinPalette { ClockinThemeChoice.selected(themeRaw).palette }

    private var weeks: [[Date]] {
        let today = calendar.startOfDay(for: now)
        let weekday = calendar.component(.weekday, from: today)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        let currentWeek = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
        return (0..<26).compactMap { index in
            guard let start = calendar.date(byAdding: .weekOfYear, value: index - 25, to: currentWeek) else { return nil }
            return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        }
    }

    private var visibleDays: [Date] { weeks.flatMap { $0 }.filter { $0 <= calendar.startOfDay(for: now) } }
    private func makeDailyStats(at date: Date) -> [Date: DayStats] {
        var result: [Date: DayStats] = [:]
        for session in store.sessions {
            let day = calendar.startOfDay(for: session.start)
            var old = result[day] ?? DayStats()
            old.duration += session.duration
            old.earnings += store.earnings(for: session)
            result[day] = old
        }
        if let running = store.running {
            let day = calendar.startOfDay(for: running.start)
            var old = result[day] ?? DayStats()
            old.duration += running.elapsed(at: date)
            old.earnings += store.currentEarnings(at: date)
            result[day] = old
        }
        return result
    }

    private func stats(for date: Date) -> DayStats {
        cachedStats[calendar.startOfDay(for: date)] ?? DayStats()
    }

    private var totalHours: Double { visibleDays.reduce(0) { $0 + stats(for: $1).duration } / 3600 }
    private var bestDay: (date: Date, duration: TimeInterval)? {
        visibleDays.map { ($0, stats(for: $0).duration) }.max { $0.1 < $1.1 }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    intro
                    summary
                    heatmap
                    legend
                }
                .padding(16)
            }
        }
        .frame(width: 390, height: 650)
        .background(theme.background)
        .fontDesign(theme.fontDesign)
        .preferredColorScheme(.dark)
        .onReceive(timer) {
            now = $0
            cachedStats = makeDailyStats(at: $0)
        }
        .onAppear { cachedStats = makeDailyStats(at: now) }
        .onChange(of: store.sessions.count) { _, _ in cachedStats = makeDailyStats(at: now) }
        .task(id: store.sessions.count) {
            await exchangeRates.refresh(sessionDates: store.sessions.map(\.start))
        }
    }

    private var header: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left").frame(width: 26, height: 26)
            }.buttonStyle(.plain)
            Text("WORK HEATMAP")
                .font(.system(size: 13, weight: .black, design: theme.fontDesign))
                .tracking(1.2)
            Spacer()
            Image(systemName: "square.grid.3x3.fill").foregroundStyle(theme.accent)
        }
        .padding(.horizontal, 15).frame(height: 50)
        .background(.white.opacity(0.025))
        .overlay(alignment: .bottom) { Divider().opacity(0.25) }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("26 WEEK RHYTHM").font(.system(size: 10, weight: .black)).foregroundStyle(theme.accent).tracking(1.1)
            Text("Each square is one day. Brighter means more focused time.")
                .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
        }
    }

    private var summary: some View {
        HStack(spacing: 8) {
            stat("6 MONTHS", DurationText.compact(totalHours * 3600))
            stat("BEST DAY", bestDay.map { DurationText.compact($0.duration) } ?? "—")
            stat("ACTIVE DAYS", "\(visibleDays.filter { stats(for: $0).duration > 0 }.count)")
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 8, weight: .bold)).foregroundStyle(.secondary).tracking(0.7)
            Text(value).font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundStyle(theme.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 9))
    }

    private var heatmap: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 6) {
                VStack(spacing: 3) {
                    Text("").frame(height: 17)
                    ForEach(["M", "W", "F"], id: \.self) { day in
                        Text(day).font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(.tertiary).frame(height: 12)
                        if day != "F" { Spacer().frame(height: 3) }
                    }
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    ScrollViewReader { proxy in
                        HStack(alignment: .top, spacing: 3) {
                            ForEach(Array(weeks.enumerated()), id: \.offset) { index, week in
                                VStack(spacing: 3) {
                                    Text(monthLabel(for: index, week: week))
                                        .font(.system(size: 8, weight: .medium))
                                        .foregroundStyle(.tertiary)
                                        .frame(height: 17, alignment: .leading)
                                    ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                                        heatCell(day)
                                    }
                                }
                                .id(index)
                            }
                        }
                        .padding(.bottom, 4)
                        .onAppear {
                            proxy.scrollTo(weeks.count - 1, anchor: .trailing)
                        }
                    }
                }
            }
            if let hoveredDate { hoverTooltip(for: hoveredDate) }
        }
        .padding(12)
        .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 12))
    }

    private func heatCell(_ date: Date) -> some View {
        let hours = stats(for: date).duration / 3600
        let isFuture = date > calendar.startOfDay(for: now)
        return ZStack {
            Color.clear
            RoundedRectangle(cornerRadius: 2)
                .fill(isFuture ? .clear : heatColor(hours: hours))
                .frame(width: 11, height: 11)
                .overlay(RoundedRectangle(cornerRadius: 2).stroke(.white.opacity(isFuture ? 0.025 : 0.04)))
        }
            .frame(width: 18, height: 18)
            .contentShape(Rectangle())
            .onHover { inside in
                withAnimation(.easeOut(duration: 0.05)) {
                    if inside { hoveredDate = date }
                    else if hoveredDate == date { hoveredDate = nil }
                }
            }
    }

    private func hoverTooltip(for date: Date) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar").foregroundStyle(theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.system(size: 10, weight: .bold))
                let dayStats = stats(for: date)
                Text("\(DurationText.compact(dayStats.duration)) • \(dayStats.earnings.money(code: store.currencyCode))")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                if store.currencyCode == "USD" {
                    if let rate = exchangeRates.rate(on: date) ?? exchangeRates.latestRate {
                        Text("≈ \((dayStats.earnings * rate).money(code: "TRY")) • 1 USD = \(String(format: "%.3f", rate)) TRY")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundStyle(theme.accent)
                    } else {
                        Text("TRY rate is still loading…")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    }

    private func monthLabel(for index: Int, week: [Date]) -> String {
        guard let firstDay = week.first(where: { calendar.component(.day, from: $0) == 1 }) else {
            return index == 0 ? week[0].formatted(.dateTime.month(.abbreviated)) : ""
        }
        return firstDay.formatted(.dateTime.month(.abbreviated))
    }

    private func heatColor(hours: Double) -> Color {
        guard hours > 0 else { return .white.opacity(0.07) }
        return theme.accent.opacity(min(1, 0.25 + hours / 8 * 0.75))
    }

    private var legend: some View {
        HStack(spacing: 5) {
            Text("Less").font(.system(size: 8)).foregroundStyle(.tertiary)
            ForEach([0.0, 0.5, 2.0, 4.0, 8.0], id: \.self) { value in
                RoundedRectangle(cornerRadius: 2).fill(heatColor(hours: value)).frame(width: 11, height: 11)
            }
            Text("More").font(.system(size: 8)).foregroundStyle(.tertiary)
            Spacer()
            Text("Hover for hours + earnings").font(.system(size: 8)).foregroundStyle(.tertiary)
        }
    }
}
