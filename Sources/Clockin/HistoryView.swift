import Charts
import SwiftUI

private enum HistoryRange: String, CaseIterable, Identifiable {
    case week = "7D"
    case month = "30D"
    case quarter = "3M"
    case all = "ALL"
    var id: String { rawValue }
    var days: Int? { switch self { case .week: 7; case .month: 30; case .quarter: 90; case .all: nil } }
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
    @State private var range: HistoryRange = .month
    @State private var showTRY = true
    private var chartInTRY: Bool { showTRY && store.currencyCode == "USD" }
    @State private var pendingDelete: WorkSession?
    @State private var hoveredDate: Date?
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
            VStack(spacing: S(0)) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: S(14)) {
                        summary(at: context.date)
                    ClockinSegmented(selection: $range, options: HistoryRange.allCases.map { (value: $0, label: $0 == .all ? "All" : $0.rawValue) })
                    chartCard(at: context.date)
                    HStack {
                        Text(groupByDay
                             ? "By day • \(filteredDays.count)"
                             : "Sessions • \(filteredSessions.count)")
                            .font(.system(size: S(10), weight: .bold)).foregroundStyle(.secondary)
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
                    Text("\(range.rawValue) • \(totals.includesActive ? "includes active" : "completed") • \((totals.earnings * rate).money(code: "TRY"))")
                        .font(.system(size: S(11))).foregroundStyle(theme.accent)
                } else {
                    Text("\(range.rawValue) • \(totals.includesActive ? "includes active" : "completed")")
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
        let activeIncluded: Bool
        if let days = range.days,
           let cutoff = Calendar.current.date(byAdding: .day, value: -days + 1, to: date) {
            activeIncluded = running.start >= Calendar.current.startOfDay(for: cutoff)
        } else {
            activeIncluded = true
        }
        guard activeIncluded else { return (completedDuration, completedEarnings, false) }
        return (completedDuration + running.elapsed(at: date), completedEarnings + store.currentEarnings(at: date), true)
    }

    private func chartCard(at date: Date) -> some View {
        let chartPoints = points(at: date)
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
                        Text(store.currencyCode == "USD" ? "Hover a bar for hours, USD, TRY and daily rate" : "Hover a bar for hours and earnings")
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
                    Chart(chartPoints) { point in
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
                    .chartPlotStyle { plot in plot.padding(.top, S(10)) }
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
                averagesStrip(chartPoints)
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
        return VStack(alignment: .leading, spacing: S(5)) {
            Text("Averages • calendar days (\(Int(calendarDays)))")
                .font(.system(size: S(10), weight: .bold)).foregroundStyle(.secondary)
            HStack(spacing: S(7)) {
            averageChip("Daily avg", hours: daily)
            averageChip("Weekly avg", hours: daily * 7)
            averageChip("Monthly avg", hours: daily * 30.44)
            }
            HStack(spacing: S(7)) {
                metricChip("Active days", value: "\(activeDays)")
                averageChip("Active-day avg", hours: activeDayAverage)
            }
        }
    }

    private func selectedCalendarDays(at date: Date) -> Double {
        let calendar = Calendar.autoupdatingCurrent
        if let days = range.days { return Double(days) }
        guard let earliest = store.sessions.map(\.start).min() else { return 1 }
        let start = calendar.startOfDay(for: earliest)
        let end = calendar.startOfDay(for: date)
        return max(1, Double(calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1)
    }

    private func averageChip(_ label: String, hours: Double) -> some View {
        let minutes = max(0, Int((hours * 60).rounded()))
        return VStack(alignment: .leading, spacing: S(2)) {
            Text(label).font(ClockinFont.caption).foregroundStyle(.secondary)
            Text("\(minutes / 60)h \(minutes % 60)m").font(.system(size: S(10), weight: .semibold, design: .monospaced))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, S(6)).padding(.horizontal, S(7))
        .background(theme.control, in: RoundedRectangle(cornerRadius: S(7)))
    }

    private func metricChip(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: S(2)) {
            Text(label).font(ClockinFont.caption).foregroundStyle(.secondary)
            Text(value).font(.system(size: S(10), weight: .semibold, design: .monospaced))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, S(6)).padding(.horizontal, S(7))
        .background(theme.control, in: RoundedRectangle(cornerRadius: S(7)))
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
        HStack(spacing: S(11)) {
            VStack(alignment: .leading, spacing: S(4)) {
                HStack(spacing: S(6)) {
                    Text(session.start.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                        .font(.system(size: S(12), weight: .semibold))
                    if let source = session.matchedExternalSource {
                        Label("Matched \(source)", systemImage: "checkmark.seal.fill")
                            .font(.system(size: S(10), weight: .bold)).foregroundStyle(theme.secondary)
                    }
                }
                Text("\(session.start.formatted(date: .omitted, time: .shortened)) – \(session.end.formatted(date: .omitted, time: .shortened))  •  \(session.note.isEmpty ? session.source : session.note)")
                    .font(.system(size: S(10))).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: S(3)) {
                Text(store.earnings(for: session).money(code: store.currencyCode)).font(.system(size: S(11), weight: .semibold))
                if store.currencyCode == "USD", let rate = exchangeRates.rate(on: session.start) {
                    Text((store.earnings(for: session) * rate).money(code: "TRY")).font(.system(size: S(10))).foregroundStyle(theme.accent)
                } else {
                    Text(DurationText.compact(session.duration)).font(.system(size: S(10))).foregroundStyle(.secondary)
                }
            }
            Button { editingSession = session } label: {
                Image(systemName: "pencil").font(.system(size: S(10))).foregroundStyle(.secondary)
            }
            .buttonStyle(.clockinIcon(size: 28))
            .help("Edit times or note").accessibilityLabel("Edit times or note")
            Button { pendingDelete = session } label: {
                Image(systemName: "trash").font(.system(size: S(10))).foregroundStyle(.secondary)
            }
            .buttonStyle(.clockinIcon(size: 28, destructive: true))
            .help("Delete this session").accessibilityLabel("Delete this session")
        }
        .padding(S(12)).background(card)
    }

    private var filteredSessions: [WorkSession] {
        guard let days = range.days, let cutoff = Calendar.current.date(byAdding: .day, value: -days + 1, to: .now) else { return store.sessions }
        return store.sessions.filter { $0.start >= Calendar.current.startOfDay(for: cutoff) }
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
                let included = range.days.flatMap { calendar.date(byAdding: .day, value: -$0 + 1, to: date) }
                .map { day >= calendar.startOfDay(for: $0) } ?? true
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
