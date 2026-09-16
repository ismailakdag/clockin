import Charts
import SwiftUI

private enum HistoryRange: String, CaseIterable, Identifiable {
    case week = "7D"
    /// The calendar month so far: work months start on the 1st.
    case thisMonth = "Month"
    case month = "30D"
    case quarter = "3M"
    case all = "ALL"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week: "Last 7 days"
        case .thisMonth: "This month"
        case .month: "Last 30 days"
        case .quarter: "Last 3 months"
        case .all: "All time"
        }
    }

    /// The first day this range covers, or nil for everything.
    func start(at date: Date, calendar: Calendar = .autoupdatingCurrent) -> Date? {
        let today = calendar.startOfDay(for: date)
        return switch self {
        case .week: calendar.date(byAdding: .day, value: -6, to: today)
        case .thisMonth: calendar.dateInterval(of: .month, for: today)?.start
        case .month: calendar.date(byAdding: .day, value: -29, to: today)
        case .quarter: calendar.date(byAdding: .day, value: -89, to: today)
        case .all: nil
        }
    }

    /// Calendar days the range covers, for the averages.
    func dayCount(at date: Date, calendar: Calendar = .autoupdatingCurrent) -> Double? {
        guard let start = start(at: date, calendar: calendar) else { return nil }
        let days = calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: date)).day ?? 0
        return max(1, Double(days) + 1)
    }
}

private struct DailyEarning: Identifiable {
    let date: Date
    let duration: TimeInterval
    let usd: Double
    let tryValue: Double?
    var id: Date { date }
}

struct HistoryView: View {
    @AppStorage(UIScale.key) private var uiScaleObserver = UIScale.defaultPercent
    @EnvironmentObject private var store: ClockStore
    @EnvironmentObject private var exchangeRates: ExchangeRateStore
    // Work months start on the 1st, so History opens on this month.
    @AppStorage("Clockin.HistoryRange") private var rangeRaw = HistoryRange.thisMonth.rawValue
    private var range: HistoryRange { HistoryRange(rawValue: rangeRaw) ?? .thisMonth }
    @State private var showTRY = true
    private var chartInTRY: Bool { showTRY && store.currencyCode == "USD" }
    @State private var pendingDelete: WorkSession?
    @State private var hoveredDate: Date?
    @State private var hoveredSession: UUID?
    @State private var showAllSessions = false
    @State private var showManualEntry = false
    @State private var editingSession: WorkSession?
    @AppStorage("Clockin.HistoryGroupByDay") private var groupByDay = true
    @State private var expandedDays: Set<Date> = []
    @AppStorage("Clockin.Theme") private var themeRaw = ClockinThemeChoice.carbon.rawValue
    private var theme: ClockinPalette { ClockinThemeChoice.selected(themeRaw).palette }
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let chartPoints = points(at: context.date)
            VStack(spacing: S(0)) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: S(20)) {
                        summary(at: context.date)
                    ClockinSegmented(selection: $rangeRaw, options: HistoryRange.allCases.map { (value: $0.rawValue, label: $0 == .all ? "All" : $0.rawValue) })
                    chartCard(chartPoints)
                    averagesStrip(chartPoints)
                    HStack {
                        Text(groupByDay
                             ? "By day • \(filteredDays.count)"
                             : "Sessions • \(filteredSessions.count)")
                            .font(ClockinFont.section).foregroundStyle(.secondary)
                        Spacer()
                        Button(groupByDay ? "Sessions" : "By day") { groupByDay.toggle() }
                            .buttonStyle(.clockin(.tinted, size: .small)).font(.system(size: S(10), weight: .bold)).foregroundStyle(theme.accent)
                        if (groupByDay ? filteredDays.count : filteredSessions.count) > 30 {
                            Button(showAllSessions ? "Show recent" : "Show all") { showAllSessions.toggle() }
                                .buttonStyle(.clockin(.tinted, size: .small)).font(.system(size: S(10), weight: .bold)).foregroundStyle(theme.accent)
                                .padding(.leading, S(10))
                        }
                    }
                    LazyVStack(spacing: S(8)) {
                        if groupByDay {
                            ForEach(visibleDays) { day in dayRow(day) }
                        } else {
                            ForEach(visibleSessions) { session in historyRow(session) }
                        }
                    }
                    }
                    .padding(S(16))
                }
            }
        }
        .fontDesign(theme.fontDesign)
        .clockinTextStyles()
        .sheet(isPresented: $showManualEntry) {
            ManualEntryView().environmentObject(store)
        }
        .sheet(item: $editingSession) { session in
            ManualEntryView(editing: session).environmentObject(store)
        }
        .alert("Delete this session?", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )) {
            Button("Keep", role: .cancel) { pendingDelete = nil }
            Button("Delete", role: .destructive) {
                if let session = pendingDelete { store.deleteSession(id: session.id) }
                pendingDelete = nil
            }
        } message: {
            Text("Its time and earnings will be removed permanently.")
        }
    }

    private var header: some View {
        ClockinScreenHeader(title: "History") {
            Button { showManualEntry = true } label: { Image(systemName: "plus") }
                .buttonStyle(.clockinIcon(tint: theme.accent))
                .help("Add a past entry by hand").accessibilityLabel("Add a past entry")
            if store.currencyCode == "USD" {
                Button(showTRY ? "TRY" : "USD") { showTRY.toggle() }
                    .buttonStyle(.clockin(.tinted, size: .small))
                    .help("Switch chart currency")
            }
        }
        .overlay(alignment: .bottom) { Divider().opacity(0.25) }
    }

    private func summary(at date: Date) -> some View {
        let totals = scopedTotals(at: date)
        return HStack {
            VStack(alignment: .leading, spacing: S(4)) {
                Text("Total earned").font(ClockinFont.section).foregroundStyle(.secondary)
                Text(totals.earnings.money(code: store.currencyCode))
                    .font(.system(size: S(25), weight: .bold, design: .rounded))
                if store.currencyCode == "USD", let rate = exchangeRates.latestRate {
                    Text("\(range.title) • \(totals.includesActive ? "includes active" : "completed") • \((totals.earnings * rate).money(code: "TRY"))")
                        .font(.system(size: S(11))).foregroundStyle(theme.accent)
                } else {
                    Text("\(range.title) • \(totals.includesActive ? "includes active" : "completed")")
                        .font(.system(size: S(11))).foregroundStyle(theme.accent)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: S(4)) {
                Text(DurationText.compact(totals.duration)).font(.system(size: S(15), weight: .semibold, design: .rounded))
                Text("\(filteredSessions.count) sessions").font(.system(size: S(10))).foregroundStyle(.secondary)
            }
        }
        .padding(S(15)).background(card)
    }

    private func scopedTotals(at date: Date) -> (duration: TimeInterval, earnings: Double, includesActive: Bool) {
        let completedDuration = filteredSessions.reduce(0) { $0 + $1.duration }
        let completedEarnings = filteredSessions.reduce(0) { $0 + store.earnings(for: $1) }
        guard let running = store.running else {
            return (completedDuration, completedEarnings, false)
        }
        let activeIncluded = range.start(at: date).map { running.start >= $0 } ?? true
        guard activeIncluded else { return (completedDuration, completedEarnings, false) }
        return (completedDuration + running.elapsed(at: date), completedEarnings + store.currentEarnings(at: date), true)
    }

    private func chartCard(_ chartPoints: [DailyEarning]) -> some View {
        return VStack(alignment: .leading, spacing: S(10)) {
            HStack {
                Text("Daily earnings").font(ClockinFont.section).foregroundStyle(.secondary)
                Spacer()
                Text(chartInTRY ? "Historical daily TRY" : store.currencyCode)
                    .font(.system(size: S(10))).foregroundStyle(.secondary)
            }
            Group {
                if let point = hoveredPoint(in: chartPoints) {
                    hoverSummary(point)
                } else {
                    HStack {
                        Image(systemName: "cursorarrow.motionlines").foregroundStyle(.secondary)
                        Text(store.currencyCode == "USD" ? "Hover a point for hours, USD, TRY and daily rate" : "Hover a point for hours and earnings")
                            .font(.system(size: S(10))).foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: S(42), maxHeight: S(42), alignment: .leading)
            .padding(.horizontal, S(9))
            .background(theme.control, in: RoundedRectangle(cornerRadius: S(9)))
            if chartPoints.isEmpty {
                Text("No earnings in this period.").font(.system(size: S(11))).foregroundStyle(.secondary).frame(height: S(120))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    Chart {
                        ForEach(chartPoints) { point in
                        let value = chartInTRY ? (point.tryValue ?? 0) : point.usd
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Earnings", value)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(theme.accent)
                        .lineStyle(StrokeStyle(lineWidth: S(2.5), lineCap: .round, lineJoin: .round))
                        AreaMark(
                            x: .value("Date", point.date),
                            y: .value("Earnings", value)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(theme.accent.opacity(0.14).gradient)
                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Earnings", value)
                        )
                        .foregroundStyle(theme.accent)
                        .symbolSize(52)
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: min(4, chartPoints.count))) { value in
                            AxisValueLabel {
                                if let date = value.as(Date.self) {
                                    Text(date, format: .dateTime.day().month(.abbreviated))
                                        .font(.system(size: S(10), weight: .medium, design: .rounded))
                                        .lineLimit(1).minimumScaleFactor(0.7)
                                }
                            }
                            AxisGridLine().foregroundStyle(theme.cardStroke)
                        }
                        // Where each work month starts, so the 1st is easy to find.
                        AxisMarks(values: monthStarts(in: chartPoints)) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                                .foregroundStyle(theme.secondary.opacity(0.5))
                            AxisValueLabel {
                                if let date = value.as(Date.self) {
                                    Text(date, format: .dateTime.month(.abbreviated))
                                        .font(.system(size: S(10), weight: .bold, design: .rounded))
                                        .foregroundStyle(theme.secondary)
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine().foregroundStyle(theme.cardStroke)
                            AxisValueLabel {
                                if let number = value.as(Double.self) { Text(number, format: .number.notation(.compactName)) }
                            }
                        }
                    }
                    .chartYScale(domain: 0...chartMaximum)
                    .chartPlotStyle { plot in plot.padding(.top, S(18)) }
                    .chartOverlay { proxy in
                        GeometryReader { geometry in
                            Rectangle().fill(.clear).contentShape(Rectangle())
                                .onContinuousHover { phase in
                                    switch phase {
                                    case .active(let location):
                                        guard let anchor = proxy.plotFrame else { return }
                                        let frame = geometry[anchor]
                                        let relativeX = location.x - frame.minX
                                        guard relativeX >= 0, relativeX <= frame.width,
                                              let date: Date = proxy.value(atX: relativeX) else { return }
                                        hoveredDate = chartPoints.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })?.date
                                    case .ended:
                                        hoveredDate = nil
                                    }
                                }
                        }
                    }
                    .frame(width: max(390, CGFloat(chartPoints.count) * 30), height: S(180))
                }
            }
        }
        .padding(S(14)).background(card)
    }

    private func averagesStrip(_ values: [DailyEarning]) -> some View {
        let totalHours = values.reduce(0) { $0 + $1.duration } / 3600
        let calendarDays = selectedCalendarDays(at: .now)
        let activeDays = values.filter { $0.duration > 0 }.count
        let daily = totalHours / calendarDays
        let activeDayAverage = totalHours / Double(max(activeDays, 1))
        return VStack(alignment: .leading, spacing: S(12)) {
            HStack {
                Text("Averages").font(ClockinFont.section)
                Spacer()
                Text("\(Int(calendarDays)) calendar days").font(ClockinFont.caption).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], alignment: .leading, spacing: S(14)) {
                averageChip("Daily", hours: daily)
                averageChip("Weekly", hours: daily * 7)
                averageChip("Monthly", hours: daily * 30.44)
                averageChip("Per active day", hours: activeDayAverage)
                metricChip("Active days", value: "\(activeDays)")
            }
        }
        .padding(S(16)).background(card)
    }

    private func selectedCalendarDays(at date: Date) -> Double {
        let calendar = Calendar.autoupdatingCurrent
        if let days = range.dayCount(at: date) { return days }
        guard let earliest = store.sessions.map(\.start).min() else { return 1 }
        let start = calendar.startOfDay(for: earliest)
        let end = calendar.startOfDay(for: date)
        return max(1, Double(calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1)
    }

    private func averageChip(_ label: String, hours: Double) -> some View {
        let minutes = max(0, Int((hours * 60).rounded()))
        return metricChip(label, value: "\(minutes / 60)h \(minutes % 60)m")
    }

    private func metricChip(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: S(5)) {
            Text(label).font(ClockinFont.caption).foregroundStyle(.secondary)
            Text(value).font(ClockinFont.body.monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func hoverSummary(_ point: DailyEarning) -> some View {
        HStack(spacing: S(10)) {
            VStack(alignment: .leading, spacing: S(2)) {
            Text(point.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                .font(.system(size: S(10), weight: .bold))
                Text("\(DurationText.compact(point.duration)) worked")
                    .font(.system(size: S(10))).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: S(2)) {
                Text(point.usd.money(code: store.currencyCode)).font(.system(size: S(10), weight: .semibold))
            if let value = point.tryValue, point.usd > 0 {
                    Text("\(value.money(code: "TRY")) • rate \(String(format: "%.3f", value / point.usd))")
                        .font(.system(size: S(10), design: .monospaced)).foregroundStyle(theme.accent)
                }
            }
        }
    }

    private func dayRow(_ day: DaySessions) -> some View {
        let expanded = expandedDays.contains(day.day)
        let earnings = day.sessions.reduce(0) { $0 + store.earnings(for: $1) }
        return VStack(alignment: .leading, spacing: S(8)) {
            Button {
                if expanded { expandedDays.remove(day.day) } else { expandedDays.insert(day.day) }
            } label: {
            HStack(spacing: S(11)) {
                Image(systemName: expanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: S(10), weight: .bold)).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: S(4)) {
                    Text(day.day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                        .font(.system(size: S(12), weight: .semibold))
                    Text("\(day.sessions.count) \(day.sessions.count == 1 ? "session" : "sessions")  •  \(day.first.formatted(date: .omitted, time: .shortened)) – \(day.last.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: S(10))).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: S(3)) {
                    Text(earnings.money(code: store.currencyCode)).font(.system(size: S(11), weight: .semibold))
                    Text(DurationText.compact(day.duration)).font(.system(size: S(10))).foregroundStyle(.secondary)
                }
            }
            }
            .buttonStyle(.clockin(.secondary, size: .small, fullWidth: true))
            .accessibilityValue(expanded ? "Expanded" : "Collapsed")

            if expanded {
                VStack(spacing: S(6)) {
                    ForEach(day.sessions) { session in historyRow(session) }
                }
                .padding(.leading, S(0))
            }
        }
        .padding(S(12)).background(card)
    }

    private func historyRow(_ session: WorkSession) -> some View {
        VStack(alignment: .leading, spacing: S(10)) {
            HStack(alignment: .top, spacing: S(12)) {
                VStack(alignment: .leading, spacing: S(5)) {
                    Text(session.start.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                        .font(ClockinFont.body)
                    Text("\(session.start.formatted(date: .omitted, time: .shortened)) – \(session.end.formatted(date: .omitted, time: .shortened))")
                        .font(ClockinFont.caption).foregroundStyle(.secondary)
                    if !Calendar.current.isDate(session.start, inSameDayAs: session.end) {
                        Text("Ends \(session.end.formatted(.dateTime.month(.abbreviated).day()))")
                            .font(ClockinFont.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: S(4))
                VStack(alignment: .trailing, spacing: S(5)) {
                    Text(store.earnings(for: session).money(code: store.currencyCode))
                        .font(ClockinFont.body.monospacedDigit())
                    Text(DurationText.compact(session.duration))
                        .font(ClockinFont.caption.monospacedDigit()).foregroundStyle(.secondary)
                    if store.currencyCode == "USD", let rate = exchangeRates.rate(on: session.start) {
                        Text((store.earnings(for: session) * rate).money(code: "TRY"))
                            .font(ClockinFont.caption).foregroundStyle(theme.accent)
                    }
                }
            }
            HStack(spacing: S(8)) {
                VStack(alignment: .leading, spacing: S(3)) {
                    Text(session.note.isEmpty ? session.source : session.note)
                        .font(ClockinFont.caption).foregroundStyle(.secondary).lineLimit(2)
                        .help(session.note.isEmpty ? session.source : session.note)
                    if let source = session.matchedExternalSource {
                        Label("Matched \(source)", systemImage: "checkmark.seal.fill")
                            .font(ClockinFont.caption).foregroundStyle(theme.secondary)
                    }
                }
                Spacer(minLength: S(4))
                Button { editingSession = session } label: { Image(systemName: "pencil") }
                    .buttonStyle(.clockinIcon(size: 26))
                    .help("Edit times or note").accessibilityLabel("Edit times or note")
                Button { pendingDelete = session } label: { Image(systemName: "trash") }
                    .buttonStyle(.clockinIcon(size: 26, destructive: true))
                    .help("Delete this session").accessibilityLabel("Delete this session")
            }
            .opacity(hoveredSession == session.id ? 1 : 0.8)
        }
        .padding(S(14)).background(card)
        .onHover { inside in hoveredSession = inside ? session.id : nil }
    }

    private var filteredSessions: [WorkSession] {
        guard let start = range.start(at: .now) else { return store.sessions }
        return store.sessions.filter { $0.start >= start }
    }

    private var visibleSessions: [WorkSession] {
        showAllSessions ? filteredSessions : Array(filteredSessions.prefix(30))
    }

    /// Bir gunun oturumlari. Kayitlar birlestirilmez; yalnizca gosterim
    /// icin toplanir, boylece CSV eslestirmesi ve tek tek silme bozulmaz.
    struct DaySessions: Identifiable {
        let day: Date
        let sessions: [WorkSession]
        var id: Date { day }
        var duration: TimeInterval { sessions.reduce(0) { $0 + $1.duration } }
        var first: Date { sessions.map(\.start).min() ?? day }
        var last: Date { sessions.map(\.end).max() ?? day }
    }

    private var filteredDays: [DaySessions] {
        let calendar = Calendar.autoupdatingCurrent
        var grouped: [Date: [WorkSession]] = [:]
        for session in filteredSessions {
            grouped[calendar.startOfDay(for: session.start), default: []].append(session)
        }
        return grouped
            .map { DaySessions(day: $0.key, sessions: $0.value.sorted { $0.start < $1.start }) }
            .sorted { $0.day > $1.day }
    }

    private var visibleDays: [DaySessions] {
        showAllSessions ? filteredDays : Array(filteredDays.prefix(30))
    }

    private func points(at date: Date) -> [DailyEarning] {
        let calendar = Calendar.autoupdatingCurrent
        var totals: [Date: (duration: TimeInterval, usd: Double)] = [:]
        for session in filteredSessions {
            let day = calendar.startOfDay(for: session.start)
            let old = totals[day] ?? (0, 0)
            totals[day] = (old.duration + session.duration, old.usd + store.earnings(for: session))
        }
        if let running = store.running {
            let day = calendar.startOfDay(for: running.start)
            let included = range.start(at: date, calendar: calendar).map { day >= $0 } ?? true
            if included {
                let old = totals[day] ?? (0, 0)
                totals[day] = (old.duration + store.elapsed(at: date), old.usd + store.currentEarnings(at: date))
            }
        }
        return totals.map { date, value in
            DailyEarning(date: date, duration: value.duration, usd: value.usd,
                         tryValue: store.currencyCode == "USD"
                            ? (exchangeRates.rate(on: date) ?? exchangeRates.latestRate).map { value.usd * $0 } : nil)
        }.sorted { $0.date < $1.date }
    }

    /// The first of each month covered by the chart, skipping a marker on the
    /// very first point where it would sit on the axis.
    private func monthStarts(in points: [DailyEarning]) -> [Date] {
        guard let first = points.first?.date, let last = points.last?.date else { return [] }
        let calendar = Calendar.autoupdatingCurrent
        var starts: [Date] = []
        var cursor = calendar.dateInterval(of: .month, for: first)?.start ?? first
        while cursor <= last {
            if cursor > first { starts.append(cursor) }
            guard let next = calendar.date(byAdding: .month, value: 1, to: cursor) else { break }
            cursor = next
        }
        return starts
    }

    private func hoveredPoint(in values: [DailyEarning]) -> DailyEarning? {
        guard let hoveredDate else { return nil }
        return values.first { Calendar.current.isDate($0.date, inSameDayAs: hoveredDate) }
    }

    private var chartMaximum: Double {
        let values = points(at: .now).map { chartInTRY ? ($0.tryValue ?? 0) : $0.usd }
        return max(1, (values.max() ?? 0) * 1.22)
    }

    private var card: some View {
        RoundedRectangle(cornerRadius: S(15), style: .continuous)
            .fill(theme.card)
            .overlay(RoundedRectangle(cornerRadius: S(15)).stroke(theme.cardStroke))
    }
}
