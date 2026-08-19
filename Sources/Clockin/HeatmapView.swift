import SwiftUI

private enum HeatmapRange: String, CaseIterable, Identifiable {
    case week = "Week"
    case month = "Month"
    case all = "All"
    var id: String { rawValue }
}

struct HeatmapView: View {
    @AppStorage(UIScale.key) private var uiScaleObserver = 1.0
    private struct DayStats {
        var duration: TimeInterval = 0
        var earnings: Double = 0
    }

    @EnvironmentObject private var store: ClockStore
    @EnvironmentObject private var exchangeRates: ExchangeRateStore
    @AppStorage("Clockin.Theme") private var themeRaw = ClockinThemeChoice.carbon.rawValue
    @AppStorage("Clockin.HeatmapRange") private var rangeRaw = HeatmapRange.all.rawValue
    @State private var now = Date()
    @State private var hoveredDate: Date?
    @State private var cachedStats: [Date: DayStats] = [:]
    @State private var cachedAggregateStats: [Date: DayStats] = [:]
    let onBack: () -> Void

    private let calendar: Calendar = {
        var value = Calendar.autoupdatingCurrent
        value.firstWeekday = 2
        return value
    }()
    private let timer = Timer.publish(every: 20, on: .main, in: .common).autoconnect()
    private var theme: ClockinPalette { ClockinThemeChoice.selected(themeRaw).palette }
    private var selectedRange: HeatmapRange { HeatmapRange(rawValue: rangeRaw) ?? .all }

    private var today: Date { calendar.startOfDay(for: now) }

    private func weekStart(for date: Date) -> Date {
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: -offset, to: day) ?? day
    }

    private var dataBounds: (start: Date, end: Date) {
        let earliest = store.sessions.map(\.start).min() ?? store.running?.start ?? today
        return (calendar.startOfDay(for: earliest), today)
    }

    private var weeks: [[Date]] {
        let bounds = dataBounds
        let first = weekStart(for: bounds.start)
        let last = weekStart(for: bounds.end)
        var starts: [Date] = []
        var cursor = first
        while cursor <= last {
            starts.append(cursor)
            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: cursor) else { break }
            cursor = next
        }
        return starts.map { start in
            (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        }
    }

    private var visibleDays: [Date] {
        let bounds = dataBounds
        return weeks.flatMap { $0 }.filter { $0 >= bounds.start && $0 <= bounds.end && $0 <= today }
    }

    private var aggregatePeriods: [Date] {
        let bounds = dataBounds
        let first: Date
        let step: Calendar.Component
        switch selectedRange {
        case .week:
            first = weekStart(for: bounds.start)
            step = .weekOfYear
        case .month:
            first = calendar.dateInterval(of: .month, for: bounds.start)?.start ?? bounds.start
            step = .month
        case .all:
            return []
        }
        var result: [Date] = []
        var cursor = first
        while cursor <= bounds.end {
            result.append(cursor)
            guard let next = calendar.date(byAdding: step, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    private func aggregateStats(for period: Date) -> DayStats {
        let start = calendar.startOfDay(for: period)
        return cachedAggregateStats[start] ?? DayStats()
    }

    private func makeAggregateStats() -> [Date: DayStats] {
        guard selectedRange != .all else { return [:] }
        var result: [Date: DayStats] = [:]
        for period in aggregatePeriods {
            let start = calendar.startOfDay(for: period)
            let end = selectedRange == .week
                ? (calendar.date(byAdding: .day, value: 7, to: start) ?? start)
                : (calendar.date(byAdding: .month, value: 1, to: start) ?? start)
            var value = DayStats()
            for session in store.sessions where session.start >= start && session.start < end {
                value.duration += session.duration
                value.earnings += store.earnings(for: session)
            }
            if let running = store.running, running.start >= start && running.start < end {
                value.duration += running.elapsed(at: now)
                value.earnings += store.currentEarnings(at: now)
            }
            result[start] = value
        }
        return result
    }
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
        VStack(spacing: S(0)) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: S(16)) {
                    intro
                    summary
                    heatmap
                    legend
                }
                .padding(S(16))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
        .fontDesign(theme.fontDesign)
        .preferredColorScheme(theme.colorScheme)
        .onReceive(timer) {
            now = $0
            cachedStats = makeDailyStats(at: $0)
            cachedAggregateStats = makeAggregateStats()
        }
        .onAppear {
            cachedStats = makeDailyStats(at: now)
            cachedAggregateStats = makeAggregateStats()
        }
        .onChange(of: store.sessions.count) {
            cachedStats = makeDailyStats(at: now)
            cachedAggregateStats = makeAggregateStats()
        }
        .onChange(of: rangeRaw) { _, _ in cachedAggregateStats = makeAggregateStats() }
        .task(id: store.sessions.count) {
            await exchangeRates.refresh(sessionDates: store.sessions.map(\.start))
        }
    }

    private var header: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left").frame(width: S(26), height: S(26))
            }.buttonStyle(.plain)
            Text("WORK HEATMAP")
                .font(.system(size: S(13), weight: .black, design: theme.fontDesign))
                .tracking(S(1.2))
            Spacer()
            Image(systemName: "square.grid.3x3.fill").foregroundStyle(theme.accent)
        }
        .padding(.horizontal, S(15)).frame(height: S(50))
        .background(.white.opacity(0.025))
        .overlay(alignment: .bottom) { Divider().opacity(0.25) }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: S(5)) {
            HStack {
                Text("\(periodLabel) RHYTHM").font(.system(size: S(10), weight: .black)).foregroundStyle(theme.accent).tracking(S(1.1))
                Spacer()
                Picker("Range", selection: $rangeRaw) {
                    ForEach(HeatmapRange.allCases) { range in
                        Text(range.rawValue).tag(range.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: S(158))
            }
            Text((selectedRange == .all ? "Each square is one day." : (selectedRange == .week ? "Each column is one week." : "Each column is one month.")) + " Scroll horizontally to pan.")
                .font(.system(size: S(11), weight: .medium)).foregroundStyle(.secondary)
        }
    }

    private var summary: some View {
        HStack(spacing: S(8)) {
            stat(periodLabel, DurationText.compact(totalHours * 3600))
            stat("BEST DAY", bestDay.map { DurationText.compact($0.duration) } ?? "—")
            stat("ACTIVE DAYS", "\(visibleDays.filter { stats(for: $0).duration > 0 }.count)")
        }
    }

    private var periodLabel: String {
        switch selectedRange {
        case .week: return "WEEKLY"
        case .month: return "MONTHLY"
        case .all: return "DAILY / ALL"
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: S(3)) {
            Text(label).font(.system(size: S(8), weight: .bold)).foregroundStyle(.secondary).tracking(S(0.7))
            Text(value).font(.system(size: S(13), weight: .bold, design: .monospaced)).foregroundStyle(theme.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(S(9))
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: S(9)))
    }

    @ViewBuilder private var heatmap: some View {
        VStack(alignment: .leading, spacing: S(9)) {
            if selectedRange == .all { dailyGrid } else { aggregateGrid }
            if let hoveredDate { hoverTooltip(for: hoveredDate) }
        }
        .padding(S(12))
        .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: S(12)))
    }

    private var dailyGrid: some View {
        HStack(alignment: .top, spacing: S(6)) {
            VStack(spacing: S(3)) {
                Text("").frame(height: S(17))
                ForEach(["M", "W", "F"], id: \.self) { day in
                    Text(day).font(.system(size: S(8), weight: .bold, design: .monospaced)).foregroundStyle(.tertiary).frame(height: S(12))
                    if day != "F" { Spacer().frame(height: S(3)) }
                }
            }
            ScrollViewReader { proxy in
                VStack(spacing: S(5)) {
                    panControls(proxy: proxy, firstID: 0, lastID: max(0, weeks.count - 1))
                    ScrollView(.horizontal, showsIndicators: true) {
                        HStack(alignment: .top, spacing: S(3)) {
                            ForEach(Array(weeks.enumerated()), id: \.offset) { index, week in
                                VStack(spacing: S(3)) {
                                    Text(monthLabel(for: index, week: week))
                                        .font(.system(size: S(8), weight: .medium))
                                        .foregroundStyle(.tertiary)
                                        .frame(height: S(17), alignment: .leading)
                                    ForEach(Array(week.enumerated()), id: \.offset) { _, day in heatCell(day) }
                                }
                                .id(index)
                            }
                        }
                        .padding(.bottom, S(4))
                    }
                }
                .id(rangeRaw)
                .onAppear { proxy.scrollTo(max(0, weeks.count - 1), anchor: .trailing) }
            }
        }
    }

    private var aggregateGrid: some View {
        ScrollViewReader { proxy in
            VStack(spacing: S(5)) {
                if let first = aggregatePeriods.first, let last = aggregatePeriods.last {
                    panControls(proxy: proxy, firstID: first, lastID: last)
                }
                ScrollView(.horizontal, showsIndicators: true) {
                    HStack(alignment: .bottom, spacing: S(5)) {
                        ForEach(aggregatePeriods, id: \.self) { period in aggregateCell(period).id(period) }
                    }
                    .frame(minHeight: S(105), alignment: .bottom)
                    .padding(.bottom, S(4))
                }
            }
            .id(rangeRaw)
            .onAppear { if let last = aggregatePeriods.last { proxy.scrollTo(last, anchor: .trailing) } }
        }
    }

    private func panControls<ID: Hashable>(proxy: ScrollViewProxy, firstID: ID, lastID: ID) -> some View {
        HStack(spacing: S(6)) {
            Text("PAN").font(.system(size: S(7), weight: .bold)).foregroundStyle(.tertiary).tracking(S(0.8))
            Spacer()
            Button("Start") { proxy.scrollTo(firstID, anchor: .leading) }
                .buttonStyle(.plain).font(.system(size: S(8), weight: .semibold)).foregroundStyle(.secondary)
            Button("Today") { proxy.scrollTo(lastID, anchor: .trailing) }
                .buttonStyle(.plain).font(.system(size: S(8), weight: .bold)).foregroundStyle(theme.accent)
        }
    }

    private func aggregateCell(_ period: Date) -> some View {
        let value = aggregateStats(for: period)
        let maximum = max(1, aggregatePeriods.map { aggregateStats(for: $0).earnings }.max() ?? 1)
        let title: String
        switch selectedRange {
        case .week: title = period.formatted(.dateTime.month(.abbreviated).day())
        case .month: title = period.formatted(.dateTime.month(.abbreviated).year(.twoDigits))
        case .all: title = ""
        }
        return VStack(spacing: S(4)) {
            Text(title).font(.system(size: S(8), weight: .medium)).foregroundStyle(.tertiary).frame(height: S(14))
            RoundedRectangle(cornerRadius: S(4))
                .fill(heatColor(hours: value.earnings, reference: maximum))
                .frame(width: S(28), height: S(50))
                .overlay(Text(DurationText.compact(value.duration)).font(.system(size: S(7), weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.85)).rotationEffect(.degrees(-90)))
            Text(value.earnings.money(code: store.currencyCode, maxFractionDigits: 0))
                .font(.system(size: S(7), weight: .semibold, design: .monospaced)).foregroundStyle(theme.accent)
        }
        .frame(width: S(34))
        .contentShape(Rectangle())
        .onHover { inside in
            withAnimation(.easeOut(duration: 0.05)) {
                if inside { hoveredDate = period }
                else if hoveredDate == period { hoveredDate = nil }
            }
        }
    }

    private func heatCell(_ date: Date) -> some View {
        let hours = stats(for: date).duration / 3600
        let isFuture = date > today
        return ZStack {
            Color.clear
            RoundedRectangle(cornerRadius: S(2))
                .fill(!isFuture ? heatColor(hours: hours) : .clear)
                .frame(width: S(11), height: S(11))
                .overlay(RoundedRectangle(cornerRadius: S(2)).stroke(.white.opacity(!isFuture ? 0.04 : 0.02)))
        }
            .frame(width: S(18), height: S(18))
            .contentShape(Rectangle())
            .onHover { inside in
                withAnimation(.easeOut(duration: 0.05)) {
                    if inside && !isFuture { hoveredDate = date }
                    else if hoveredDate == date { hoveredDate = nil }
                }
            }
    }

    private func hoverTooltip(for date: Date) -> some View {
        let periodStats = selectedRange == .all ? stats(for: date) : aggregateStats(for: date)
        let periodTitle: String
        switch selectedRange {
        case .all: periodTitle = date.formatted(.dateTime.weekday(.wide).month(.wide).day())
        case .week:
            let end = calendar.date(byAdding: .day, value: 6, to: date) ?? date
            periodTitle = "Week of \(date.formatted(.dateTime.month(.abbreviated).day())) – \(end.formatted(.dateTime.month(.abbreviated).day()))"
        case .month: periodTitle = date.formatted(.dateTime.month(.wide).year())
        }
        return HStack(spacing: S(8)) {
            Image(systemName: "calendar").foregroundStyle(theme.accent)
            VStack(alignment: .leading, spacing: S(2)) {
                Text(periodTitle)
                    .font(.system(size: S(10), weight: .bold))
                Text("\(DurationText.compact(periodStats.duration)) • \(periodStats.earnings.money(code: store.currencyCode))")
                    .font(.system(size: S(9), weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                if store.currencyCode == "USD" {
                    if let rate = exchangeRates.rate(on: date) ?? exchangeRates.latestRate {
                        Text("≈ \((periodStats.earnings * rate).money(code: "TRY")) • 1 USD = \(String(format: "%.3f", rate)) TRY")
                            .font(.system(size: S(8), weight: .medium, design: .monospaced))
                            .foregroundStyle(theme.accent)
                    } else {
                        Text("TRY rate is still loading…")
                            .font(.system(size: S(8), weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, S(9))
        .padding(.vertical, S(7))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: S(8)))
    }

    private func monthLabel(for index: Int, week: [Date]) -> String {
        guard let firstDay = week.first(where: { calendar.component(.day, from: $0) == 1 }) else {
            return index == 0 ? week[0].formatted(.dateTime.month(.abbreviated)) : ""
        }
        return firstDay.formatted(.dateTime.month(.abbreviated))
    }

    private func heatColor(hours: Double, reference: Double = 8) -> Color {
        guard hours > 0 else { return .white.opacity(0.07) }
        return theme.accent.opacity(min(1, 0.25 + hours / max(reference, 0.1) * 0.75))
    }

    private var legend: some View {
        HStack(spacing: S(5)) {
            Text(selectedRange == .all ? "Less hours" : "Less earnings").font(.system(size: S(8))).foregroundStyle(.tertiary)
            ForEach([0.0, 0.5, 2.0, 4.0, 8.0], id: \.self) { value in
                RoundedRectangle(cornerRadius: S(2)).fill(heatColor(hours: value)).frame(width: S(11), height: S(11))
            }
            Text("More").font(.system(size: S(8))).foregroundStyle(.tertiary)
            Spacer()
            Text("Hover for hours + earnings").font(.system(size: S(8))).foregroundStyle(.tertiary)
        }
    }
}
