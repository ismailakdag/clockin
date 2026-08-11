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
    @EnvironmentObject private var store: ClockStore
    @EnvironmentObject private var exchangeRates: ExchangeRateStore
    @State private var range: HistoryRange = .month
    @State private var showTRY = true
    @State private var pendingDelete: WorkSession?
    @State private var hoveredDate: Date?
    @State private var showAllSessions = false
    @AppStorage("Clockin.Theme") private var themeRaw = ClockinThemeChoice.carbon.rawValue
    let onBack: () -> Void
    private var theme: ClockinPalette { ClockinThemeChoice.selected(themeRaw).palette }
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        summary(at: context.date)
                    Picker("Range", selection: $range) {
                        ForEach(HistoryRange.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    chartCard(at: context.date)
                    HStack {
                        Text("ALL SESSIONS • \(filteredSessions.count)")
                            .font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary).tracking(1.2)
                        Spacer()
                        if filteredSessions.count > 30 {
                            Button(showAllSessions ? "Show recent" : "Show all") { showAllSessions.toggle() }
                                .buttonStyle(.plain).font(.system(size: 9, weight: .bold)).foregroundStyle(theme.accent)
                        }
                    }
                    LazyVStack(spacing: 8) {
                        ForEach(visibleSessions) { session in historyRow(session) }
                    }
                    }
                    .padding(16)
                }
            }
        }
        .fontDesign(theme.fontDesign)
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
        HStack {
            Button(action: onBack) { Image(systemName: "chevron.left").frame(width: 26, height: 26) }
                .buttonStyle(.plain)
            Text("EARNINGS HISTORY").font(.system(size: 13, weight: .black, design: .rounded)).tracking(1.3)
            Spacer()
            Button(showTRY ? "TRY" : "USD") { showTRY.toggle() }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(theme.accent)
                .padding(.horizontal, 9).padding(.vertical, 5)
                .background(theme.accent.opacity(0.1), in: Capsule())
        }
        .padding(.horizontal, 15).frame(height: 50)
        .background(.white.opacity(0.025))
        .overlay(alignment: .bottom) { Divider().opacity(0.25) }
    }

    private func summary(at date: Date) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("TOTAL EARNED").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary).tracking(1)
                Text(store.allEarnings(at: date).money(code: store.currencyCode))
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                if store.currencyCode == "USD", let rate = exchangeRates.latestRate {
                    Text("Includes active • ≈ \((store.allEarnings(at: date) * rate).money(code: "TRY"))")
                        .font(.system(size: 11)).foregroundStyle(theme.accent)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(DurationText.compact(store.allDuration(at: date))).font(.system(size: 15, weight: .semibold, design: .rounded))
                Text("\(store.sessions.count) sessions").font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
        .padding(15).background(card)
    }

    private func chartCard(at date: Date) -> some View {
        let chartPoints = points(at: date)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("DAILY EARNINGS").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary).tracking(1)
                Spacer()
                Text(showTRY ? "Historical daily TRY" : "USD")
                    .font(.system(size: 9)).foregroundStyle(.tertiary)
            }
            Group {
                if let point = hoveredPoint(in: chartPoints) {
                    hoverSummary(point)
                } else {
                    HStack {
                        Image(systemName: "cursorarrow.motionlines").foregroundStyle(.secondary)
                        Text("Hover a bar for hours, USD, TRY and daily rate")
                            .font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 42, maxHeight: 42, alignment: .leading)
            .padding(.horizontal, 9)
            .background(.black.opacity(0.14), in: RoundedRectangle(cornerRadius: 9))
            if chartPoints.isEmpty {
                Text("No earnings in this period.").font(.system(size: 11)).foregroundStyle(.secondary).frame(height: 120)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    Chart(chartPoints) { point in
                        let value = showTRY ? (point.tryValue ?? 0) : point.usd
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Earnings", value)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(theme.accent)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
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
                                        .font(.system(size: 8, weight: .medium, design: .rounded))
                                        .lineLimit(1).minimumScaleFactor(0.7)
                                }
                            }
                            AxisGridLine().foregroundStyle(.white.opacity(0.04))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine().foregroundStyle(.white.opacity(0.06))
                            AxisValueLabel {
                                if let number = value.as(Double.self) { Text(number, format: .number.notation(.compactName)) }
                            }
                        }
                    }
                    .chartYScale(domain: 0...chartMaximum)
                    .chartPlotStyle { plot in plot.padding(.top, 10) }
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
                    .frame(width: max(390, CGFloat(chartPoints.count) * 30), height: 180)
                }
                averagesStrip(chartPoints)
            }
        }
        .padding(14).background(card)
    }

    private func averagesStrip(_ values: [DailyEarning]) -> some View {
        let daily = values.reduce(0) { $0 + $1.duration } / 3600 / Double(max(values.count, 1))
        return VStack(alignment: .leading, spacing: 5) {
            Text("AVERAGES • PROJECTED FROM SELECTED RANGE")
                .font(.system(size: 7, weight: .bold)).foregroundStyle(.tertiary).tracking(0.7)
            HStack(spacing: 7) {
            averageChip("DAILY AVG", hours: daily)
            averageChip("WEEKLY AVG", hours: daily * 7)
            averageChip("MONTHLY AVG", hours: daily * 30)
            }
        }
    }

    private func averageChip(_ label: String, hours: Double) -> some View {
        let minutes = max(0, Int((hours * 60).rounded()))
        return VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 7, weight: .bold)).foregroundStyle(.secondary)
            Text("\(minutes / 60)h \(minutes % 60)m").font(.system(size: 9, weight: .semibold, design: .monospaced))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6).padding(.horizontal, 7)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 7))
    }

    private func hoverSummary(_ point: DailyEarning) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
            Text(point.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                .font(.system(size: 9, weight: .bold))
                Text("\(DurationText.compact(point.duration)) worked")
                    .font(.system(size: 8)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 2) {
                Text(point.usd.money(code: "USD")).font(.system(size: 9, weight: .semibold))
            if let value = point.tryValue, point.usd > 0 {
                    Text("≈ \(value.money(code: "TRY")) • rate \(String(format: "%.3f", value / point.usd))")
                        .font(.system(size: 8, design: .monospaced)).foregroundStyle(theme.accent)
                }
            }
        }
    }

    private func historyRow(_ session: WorkSession) -> some View {
        HStack(spacing: 11) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(session.start.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                        .font(.system(size: 12, weight: .semibold))
                    if let source = session.matchedExternalSource {
                        Label("Matched \(source)", systemImage: "checkmark.seal.fill")
                            .font(.system(size: 8, weight: .bold)).foregroundStyle(theme.secondary)
                    }
                }
                Text("\(session.start.formatted(date: .omitted, time: .shortened)) – \(session.end.formatted(date: .omitted, time: .shortened))  •  \(session.note.isEmpty ? session.source : session.note)")
                    .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(store.earnings(for: session).money(code: store.currencyCode)).font(.system(size: 11, weight: .semibold))
                if store.currencyCode == "USD", let rate = exchangeRates.rate(on: session.start) {
                    Text((store.earnings(for: session) * rate).money(code: "TRY")).font(.system(size: 9)).foregroundStyle(theme.accent)
                } else {
                    Text(DurationText.compact(session.duration)).font(.system(size: 9)).foregroundStyle(.secondary)
                }
            }
            Button { pendingDelete = session } label: {
                Image(systemName: "trash").font(.system(size: 10)).foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12).background(card)
    }

    private var filteredSessions: [WorkSession] {
        guard let days = range.days, let cutoff = Calendar.current.date(byAdding: .day, value: -days + 1, to: .now) else { return store.sessions }
        return store.sessions.filter { $0.start >= Calendar.current.startOfDay(for: cutoff) }
    }

    private var visibleSessions: [WorkSession] {
        showAllSessions ? filteredSessions : Array(filteredSessions.prefix(30))
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
                         tryValue: (exchangeRates.rate(on: date) ?? exchangeRates.latestRate).map { value.usd * $0 })
        }.sorted { $0.date < $1.date }
    }

    private func hoveredPoint(in values: [DailyEarning]) -> DailyEarning? {
        guard let hoveredDate else { return nil }
        return values.first { Calendar.current.isDate($0.date, inSameDayAs: hoveredDate) }
    }

    private var chartMaximum: Double {
        let values = points(at: .now).map { showTRY ? ($0.tryValue ?? 0) : $0.usd }
        return max(1, (values.max() ?? 0) * 1.22)
    }

    private var card: some View {
        RoundedRectangle(cornerRadius: 15, style: .continuous)
            .fill(.white.opacity(0.045))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(.white.opacity(0.07)))
    }
}
