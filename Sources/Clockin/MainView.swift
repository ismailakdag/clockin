import AppKit
import SwiftUI

struct MainView: View {
    @AppStorage(UIScale.key) private var uiScaleObserver = 1.0
    @EnvironmentObject private var store: ClockStore
    @EnvironmentObject private var exchangeRates: ExchangeRateStore
    @State private var now = Date()
    @State private var rateText = ""
    @State private var showHistory = false
    @State private var showHeatmap = false
    @State private var showSettings = false
    @State private var showGuide = false
    @State private var showProgress = false
    @State private var showPasteImporter = false
    @State private var showCSVComparison = false
    @State private var csvPreviewSessions: [WorkSession] = []
    @State private var showManualStart = false
    @State private var confirmCancel = false
    @State private var showRateSchedule = false
    @State private var completedSummary: WorkSession?
    @AppStorage("Clockin.PinnedMode") private var pinnedMode = "Money"
    @AppStorage("Clockin.Theme") private var themeRaw = ClockinThemeChoice.carbon.rawValue
    @AppStorage("Clockin.ChimeEnabled") private var chimeEnabled = false
    @AppStorage("Clockin.ChimeSound") private var chimeSound = "Glass"
    @AppStorage("Clockin.ChimeVolume") private var chimeVolume = 0.75
    @AppStorage("Clockin.MascotEnabled") private var mascotEnabled = true
    @AppStorage("Clockin.GoalDailyHours") private var dailyGoalHours = 0.0
    @AppStorage("Clockin.GoalMonthlyHours") private var monthlyGoalHours = 0.0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private var theme: ClockinPalette { ClockinThemeChoice.selected(themeRaw).palette }

    private struct ProgressStats {
        var longestStreak: Int
        var xp: Int
        var level: Int
    }

    /// Gunluk toplamlar, en uzun seri ve XP tek gecisde hesaplanir.
    /// Ayri computed property'ler halindeyken her erisim butun oturumlari
    /// yeniden tariyordu ve header bunu saniyede 14 kez tetikliyordu.
    private var progressStats: ProgressStats {
        let calendar = Calendar.current
        var daily: [Date: TimeInterval] = [:]
        for session in store.sessions { daily[calendar.startOfDay(for: session.start), default: 0] += session.duration }
        if let running = store.running { daily[calendar.startOfDay(for: running.start), default: 0] += running.elapsed(at: now) }

        let days = daily.keys.sorted()
        var longestStreak = days.isEmpty ? 0 : 1
        var current = 1
        for pair in zip(days, days.dropFirst()) {
            if calendar.dateComponents([.day], from: pair.0, to: pair.1).day == 1 {
                current += 1
                longestStreak = max(longestStreak, current)
            } else { current = 1 }
        }

        let values = daily.values
        let goalDays = dailyGoalHours > 0 ? values.filter { $0 >= dailyGoalHours * 3600 }.count : 0
        let doubleDays = dailyGoalHours > 0 ? values.filter { $0 >= dailyGoalHours * 7200 }.count : 0
        let monthGoals: Int
        if monthlyGoalHours > 0 {
            let grouped = Dictionary(grouping: daily) { calendar.dateInterval(of: .month, for: $0.key)?.start ?? $0.key }
            monthGoals = grouped.values.map { $0.reduce(0) { $0 + $1.value } }.filter { $0 >= monthlyGoalHours * 3600 }.count
        } else { monthGoals = 0 }
        let streakXP = [(3, 100), (7, 250), (14, 500), (30, 1_000), (60, 2_000)]
            .filter { longestStreak >= $0.0 }.reduce(0) { $0 + $1.1 }

        let xp = Int((store.totalDuration + store.elapsed(at: now)) / 3600 * 100)
            + goalDays * 100 + doubleDays * 250 + monthGoals * 500 + streakXP
        return ProgressStats(longestStreak: longestStreak, xp: xp, level: max(1, xp / 500 + 1))
    }

    var body: some View {
        Group {
            if showHistory {
                HistoryView { showHistory = false }
            } else if showHeatmap {
                HeatmapView { showHeatmap = false }
            } else if showSettings {
                SettingsView { showSettings = false }
                    .environmentObject(exchangeRates)
            } else if showProgress {
                ProgressDashboardView { showProgress = false }
            } else {
                VStack(spacing: S(0)) {
                    header
                    ScrollView {
                        VStack(spacing: S(14)) {
                            timerCard
                            if mascotEnabled { mascotCard }
                            todayCard
                            goalsCard
                            exchangeCard
                            recentSection
                            footer
                        }
                        .padding(S(16))
                    }
                }
            }
        }
        // Pencerenin kok gorunumu. En kucuk olcu bildirilmezse NSHostingView
        // ideal boyutu sifir sanip pencereyi cokertiyor.
        .frame(minWidth: S(UIScale.base.width), maxWidth: .infinity,
               minHeight: S(UIScale.base.height), maxHeight: .infinity)
        .background(theme.background)
        .fontDesign(theme.fontDesign)
        .preferredColorScheme(theme.colorScheme)
        .onAppear {
            rateText = formattedRate
            if store.pinVisible { PinnedWindowController.shared.update(isVisible: true, store: store) }
        }
        .onReceive(timer) { now = $0 }
        .task(id: store.sessions.count) {
            await exchangeRates.refresh(sessionDates: store.sessions.map(\.start))
        }
        .sheet(isPresented: $showPasteImporter) {
            PasteImportView().environmentObject(store)
        }
        .sheet(isPresented: $showGuide) {
            GuideView()
        }
        .sheet(isPresented: $showCSVComparison) {
            ImportComparisonView(sessions: csvPreviewSessions, sourceTitle: "Timesheet CSV") {
                showCSVComparison = false
            }
            .environmentObject(store)
        }
        .sheet(isPresented: $showManualStart) {
            ManualStartView().environmentObject(store)
        }
        .sheet(isPresented: $showRateSchedule) {
            RateScheduleView().environmentObject(store)
        }
        .sheet(item: $completedSummary) { session in
            SessionSummaryView(session: session).environmentObject(store)
        }
        .onChange(of: store.hourlyRate) { _, newRate in
            rateText = String(format: "%.2f", newRate)
        }
        .alert("Cancel active session?", isPresented: $confirmCancel) {
            Button("Keep working", role: .cancel) {}
            Button("Cancel session", role: .destructive) { store.cancelRunning() }
        } message: {
            Text("The active time will be discarded and no earnings will be added.")
        }
    }

    private var header: some View {
        // Tek kez hesaplanip iki yerde kullanilir (LV rozeti ve help metni).
        let stats = progressStats
        return HStack {
            HStack(spacing: S(9)) {
                Image(systemName: "timer")
                    .font(.system(size: S(16), weight: .bold))
                    .foregroundStyle(theme.accent)
                Text("CLOCKIN")
                    .font(.system(size: S(14), weight: .black, design: theme.fontDesign))
                    .tracking(S(1.8))
            }
            Spacer()
            HStack(spacing: S(2)) {
                headerIcon("chart.bar.xaxis", help: "Earnings history") { showHistory = true }
                headerIcon("square.grid.3x3.fill", help: "Work heatmap") { showHeatmap = true }
                headerIcon("questionmark.circle", help: "How to use Clockin") { showGuide = true }
            }
            .padding(S(3))
            .background(theme.surface, in: RoundedRectangle(cornerRadius: S(9), style: .continuous))
            HStack(spacing: S(2)) {
                Button { showProgress = true } label: {
                    Label("LV \(stats.level)", systemImage: "trophy.fill")
                        .font(.system(size: S(9), weight: .bold, design: .monospaced))
                        .frame(width: S(52), height: S(28))
                }
                .buttonStyle(.plain).foregroundStyle(theme.accent)
                .help("Progress • \(stats.xp) XP • streaks • mascot • records")
                headerIcon("gearshape.fill", help: "Settings") { showSettings = true }
                Button { store.setPinned(!store.pinVisible) } label: {
                    Image(systemName: store.pinVisible ? "pin.fill" : "pin")
                        .frame(width: S(28), height: S(28))
                }
                .buttonStyle(.plain)
                .foregroundStyle(store.pinVisible ? theme.accent : .secondary)
                .help(store.pinVisible ? "Hide floating timer" : "Pin timer to desktop")
            }
            .padding(S(3))
            .background(theme.surface, in: RoundedRectangle(cornerRadius: S(9), style: .continuous))
        }
        .padding(.horizontal, S(18))
        .frame(height: S(50))
        .background(.white.opacity(0.025))
        .overlay(alignment: .bottom) { Divider().opacity(0.25) }
    }

    private func headerIcon(_ systemName: String, color: Color = .secondary, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName).frame(width: S(28), height: S(28))
        }
        .buttonStyle(.plain)
        .foregroundStyle(color)
        .help(help)
    }

    private var timerCard: some View {
        VStack(spacing: S(17)) {
            HStack(spacing: S(7)) {
                Circle()
                    .fill(statusColor)
                    .frame(width: S(7), height: S(7))
                    .shadow(color: statusColor.opacity(store.running?.isPaused == false ? 0.8 : 0), radius: 5)
                Text(statusText)
                    .font(.system(size: S(10), weight: .bold, design: theme.fontDesign))
                    .foregroundStyle(.secondary)
                    .tracking(S(1.3))
            }

            Text(DurationText.clock(store.elapsed(at: now)))
                .font(.system(size: S(48), weight: .medium, design: theme.fontDesign))
                .monospacedDigit()
                .tracking(-2)
                .contentTransition(.numericText())

            Text(store.currentEarnings(at: now).money(code: store.currencyCode))
                .font(.system(size: S(18), weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.accent)
                .contentTransition(.numericText())

            if store.currencyCode == "USD", let usdTry = exchangeRates.latestRate {
                Text("≈ \((store.currentEarnings(at: now) * usdTry).money(code: "TRY"))")
                    .font(.system(size: S(11), weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            moneyMomentum

            controls
        }
        .padding(S(20))
        .frame(maxWidth: .infinity)
        .background(cardBackground)
    }

    private var moneyMomentum: some View {
        let perSecond = store.hourlyRate / 3600
        let current = store.currentEarnings(at: now)
        let milestone = max(10, ceil(max(current, 0.01) / 10) * 10)
        let progress = current.truncatingRemainder(dividingBy: 10) / 10
        let isEarning = store.running?.isPaused == false
        return VStack(spacing: S(8)) {
            HStack(spacing: S(9)) {
                Image(systemName: isEarning ? "flame.fill" : "sparkles")
                    .foregroundStyle(isEarning ? .orange : theme.accent)
                VStack(alignment: .leading, spacing: S(2)) {
                    Text(isEarning ? "MONEY MOMENTUM" : "YOUR EARNING POWER")
                        .font(.system(size: S(8), weight: .black, design: .rounded)).foregroundStyle(.secondary).tracking(S(1))
                    HStack(spacing: S(5)) {
                        Text("+\(perSecond.money(code: store.currencyCode, maxFractionDigits: 4))/sec")
                        if store.currencyCode == "USD", let usdTry = exchangeRates.latestRate {
                            Text("• +\((perSecond * usdTry).money(code: "TRY", maxFractionDigits: 4))/sec")
                        }
                    }
                    .font(.system(size: S(10), weight: .semibold, design: .monospaced))
                    .foregroundStyle(isEarning ? theme.accent : .secondary)
                }
                Spacer()
                if store.running != nil {
                    VStack(alignment: .trailing, spacing: S(1)) {
                        Text("NEXT \(milestone.money(code: store.currencyCode))")
                            .font(.system(size: S(8), weight: .bold)).foregroundStyle(.secondary)
                        Text("\(max(0, milestone - current).money(code: store.currencyCode)) to go")
                            .font(.system(size: S(9), weight: .semibold))
                    }
                }
            }
            if store.running != nil {
                ProgressView(value: progress)
                    .tint(theme.accent)
                    .scaleEffect(y: 0.65)
            }
        }
        .padding(S(10))
        .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: S(10)))
    }

    @ViewBuilder private var controls: some View {
        if let running = store.running {
            VStack(spacing: S(9)) {
                HStack(spacing: S(10)) {
                    Button {
                        running.isPaused ? store.resume() : store.pause()
                    } label: {
                        Label(running.isPaused ? "Resume" : "Pause", systemImage: running.isPaused ? "play.fill" : "pause.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button {
                        completedSummary = store.clockOut()
                    } label: {
                        Label("Clock out", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DangerButtonStyle())
                }
                Button { confirmCancel = true } label: {
                    Label("Cancel session", systemImage: "xmark")
                        .font(.system(size: S(10), weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        } else {
            VStack(spacing: S(9)) {
                Button {
                    store.clockIn()
                } label: {
                    Label("Clock in", systemImage: "play.fill")
                        .font(.system(size: S(14), weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle(accent: theme.accent))
                Button { showManualStart = true } label: {
                    Label("Start with elapsed time", systemImage: "clock.arrow.circlepath")
                        .font(.system(size: S(10), weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var todayCard: some View {
        HStack(spacing: S(0)) {
            metric(title: "TODAY", value: DurationText.compact(store.todayDuration(at: now)), icon: "clock")
                .frame(maxWidth: .infinity, alignment: .leading)
            Divider().frame(height: S(35)).opacity(0.25)
            todayEarnedMetric
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, S(14))
        .background(cardBackground)
    }

    private var todayEarnedMetric: some View {
        let earned = store.todayEarnings(at: now)
        return HStack(spacing: S(10)) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .foregroundStyle(theme.accent.opacity(0.8))
                .frame(width: S(20))
            VStack(alignment: .leading, spacing: S(3)) {
                Text("EARNED").font(.system(size: S(9), weight: .bold)).foregroundStyle(.secondary).tracking(S(1))
                Text(earned.money(code: store.currencyCode)).font(.system(size: S(13), weight: .semibold, design: .rounded))
                if store.currencyCode == "USD" {
                    if let rate = exchangeRates.latestRate {
                        Text("≈ " + (earned * rate).money(code: "TRY"))
                            .font(.system(size: S(9), weight: .medium, design: .rounded))
                            .foregroundStyle(theme.accent)
                    } else {
                        Text("TRY rate unavailable")
                            .font(.system(size: S(8), weight: .medium))
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
    }

    private var mascotCard: some View {
        return HStack(spacing: S(12)) {
            ClockinMascotStage().environmentObject(store).frame(width: S(62), height: S(62))
            VStack(alignment: .leading, spacing: S(4)) {
                Text("FOCUS COMPANION").font(.system(size: S(8), weight: .black)).foregroundStyle(.secondary).tracking(S(1))
                Text(store.running?.isPaused == true ? "Taking a reset break" : (store.running == nil ? "Ready when you are" : "You are doing great — keep going!"))
                    .font(.system(size: S(11), weight: .semibold))
                Text("Open Progress with the XP button for streaks and levels")
                    .font(.system(size: S(8))).foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .padding(S(10)).background(cardBackground)
    }

    private var exchangeCard: some View {
        HStack(spacing: S(10)) {
            Image(systemName: "dollarsign.arrow.circlepath")
                .foregroundStyle(theme.secondary)
                .frame(width: S(28), height: S(28))
                .background(theme.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: S(8)))
            VStack(alignment: .leading, spacing: S(3)) {
                Text("USD / TRY").font(.system(size: S(9), weight: .bold)).foregroundStyle(.secondary).tracking(S(1))
                if let rate = exchangeRates.latestRate {
                    Text(String(format: "1 USD = %.3f TRY", rate)).font(.system(size: S(13), weight: .semibold, design: .rounded))
                    Text(rateStatusText).font(.system(size: S(9), weight: .medium)).foregroundStyle(rateStatusColor)
                } else {
                    Text(exchangeRates.isLoading ? "Fetching live rate…" : "RATE UNAVAILABLE")
                        .font(.system(size: S(11), weight: .bold))
                        .foregroundStyle(exchangeRates.isLoading ? Color.secondary : Color.red)
                }
            }
            Spacer()
            if let day = exchangeRates.latestDate {
                Text(day).font(.system(size: S(9), design: .monospaced)).foregroundStyle(.tertiary)
            }
        }
        .padding(S(12))
        .background(cardBackground)
    }

    private var goalsCard: some View {
        let daily = store.todayDuration(at: now) / 3600
        let monthly = store.monthDuration(at: now) / 3600
        let hasGoals = dailyGoalHours > 0 || monthlyGoalHours > 0
        return VStack(alignment: .leading, spacing: S(10)) {
            HStack {
                Label("GOALS", systemImage: "target").font(.system(size: S(9), weight: .bold)).foregroundStyle(.secondary).tracking(S(1))
                Spacer()
                if !hasGoals { Text("Set in Settings").font(.system(size: S(9))).foregroundStyle(.tertiary) }
            }
            if dailyGoalHours > 0 { goalRow("Today", value: daily, goal: dailyGoalHours) }
            if monthlyGoalHours > 0 { goalRow("This month", value: monthly, goal: monthlyGoalHours) }
        }
        .padding(S(12))
        .background(cardBackground)
    }

    private func goalRow(_ title: String, value: Double, goal: Double) -> some View {
        let progress = min(max(value / goal, 0), 1)
        return VStack(alignment: .leading, spacing: S(4)) {
            HStack {
                Text(title).font(.system(size: S(10), weight: .semibold))
                Spacer()
                Text(hoursText(value)).font(.system(size: S(10), weight: .bold, design: .monospaced))
                Text("/ \(hoursText(goal))").font(.system(size: S(9))).foregroundStyle(.secondary)
            }
            ProgressView(value: progress).tint(progress >= 1 ? .green : theme.accent).scaleEffect(y: 0.7)
            Text(progress >= 1 ? "Goal reached" : "\(hoursText(max(0, goal - value))) remaining")
                .font(.system(size: S(8), weight: .medium)).foregroundStyle(progress >= 1 ? .green : .secondary)
        }
    }

    private func hoursText(_ hours: Double) -> String {
        let minutes = max(0, Int((hours * 60).rounded()))
        return "\(minutes / 60)h \(minutes % 60)m"
    }

    private var rateStatusText: String {
        if exchangeRates.isLoading { return "Checking API…" }
        if let error = exchangeRates.errorMessage { return error }
        if let checked = exchangeRates.lastSuccessfulCheck {
            return "API OK • checked \(checked.formatted(date: .omitted, time: .shortened))"
        }
        return "Cached rate"
    }

    private var rateStatusColor: Color {
        if exchangeRates.errorMessage != nil { return .orange }
        return exchangeRates.isLoading ? .secondary : theme.accent
    }

    private func metric(title: String, value: String, icon: String) -> some View {
        HStack(spacing: S(10)) {
            Image(systemName: icon).foregroundStyle(theme.accent.opacity(0.8)).frame(width: S(20))
            VStack(alignment: .leading, spacing: S(3)) {
                Text(title).font(.system(size: S(9), weight: .bold)).foregroundStyle(.secondary).tracking(S(1))
                Text(value).font(.system(size: S(14), weight: .semibold, design: .rounded)).lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, S(14))
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: S(10)) {
            HStack {
                sectionTitle("RECENT SESSIONS")
                Spacer()
                if !store.sessions.isEmpty {
                    Button("View all") { showHistory = true }
                        .buttonStyle(.plain).font(.system(size: S(10), weight: .semibold)).foregroundStyle(theme.accent)
                }
            }
            if store.sessions.isEmpty {
                Text("Clock in or import a CSV to see your history.")
                    .font(.system(size: S(12)))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(S(14))
                    .background(cardBackground)
            } else {
                VStack(spacing: S(0)) {
                    ForEach(Array(store.sessions.prefix(4).enumerated()), id: \.element.id) { index, session in
                        sessionRow(session)
                        if index < min(3, store.sessions.count - 1) { Divider().opacity(0.2).padding(.leading, S(44)) }
                    }
                }
                .background(cardBackground)
            }
        }
    }

    private func sessionRow(_ session: WorkSession) -> some View {
        HStack(spacing: S(11)) {
            Image(systemName: session.source == "Clockin" ? "bolt.fill" : "arrow.down.doc.fill")
                .font(.system(size: S(11)))
                .foregroundStyle(session.source == "Clockin" ? theme.accent : theme.secondary)
                .frame(width: S(28), height: S(28))
                .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: S(8)))
            VStack(alignment: .leading, spacing: S(3)) {
                Text(session.start.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                    .font(.system(size: S(12), weight: .medium))
                Text(session.note.isEmpty ? session.source : session.note)
                    .font(.system(size: S(10)))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: S(3)) {
                Text(DurationText.compact(session.duration)).font(.system(size: S(12), weight: .semibold, design: .rounded))
                Text(store.earnings(for: session).money(code: store.currencyCode)).font(.system(size: S(10))).foregroundStyle(theme.accent)
            }
        }
        .padding(.horizontal, S(12))
        .padding(.vertical, S(10))
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: S(10)) {
            sectionTitle("PAY & DATA")
            HStack(spacing: S(10)) {
                HStack {
                    Text("Rate").foregroundStyle(.secondary)
                    Spacer()
                    TextField("0", text: $rateText)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                        .frame(width: S(72))
                        .onSubmit(commitRate)
                        .onChange(of: rateText) { _, newText in
                            let normalized = newText.replacingOccurrences(of: ",", with: ".")
                            guard let value = Double(normalized), value >= 0,
                                  abs(value - store.hourlyRate) > 0.000_001 else { return }
                            store.updateRate(value)
                        }
                    Text("/ hr").foregroundStyle(.tertiary)
                }
                .padding(S(11))
                .background(cardBackground)

                Picker("", selection: Binding(
                    get: { store.currencyCode },
                    set: { newCode in store.updateCurrency(newCode) }
                )) {
                    ForEach(["USD", "EUR", "GBP", "TRY"], id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                .frame(width: S(82))
            }

            HStack {
                VStack(alignment: .leading, spacing: S(2)) {
                    Text("RATE SCHEDULE").font(.system(size: S(9), weight: .bold)).foregroundStyle(.secondary).tracking(S(1))
                    if let date = store.currentRateEffectiveFrom {
                        Text("Current rate applies from \(date.formatted(.dateTime.month(.abbreviated).day().year()))")
                            .font(.system(size: S(9))).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button("Manage") { showRateSchedule = true }
                    .buttonStyle(.plain).font(.system(size: S(10), weight: .bold)).foregroundStyle(theme.accent)
            }
            .padding(S(10))
            .background(cardBackground)

            HStack {
                Label("Theme", systemImage: "paintpalette.fill")
                    .font(.system(size: S(11), weight: .medium)).foregroundStyle(.secondary)
                Spacer()
                Picker("Theme", selection: $themeRaw) {
                    ForEach(ClockinThemeChoice.allCases) { choice in
                        Text(choice.rawValue).tag(choice.rawValue)
                    }
                }
                .labelsHidden()
                .frame(width: S(135))
            }
            .padding(S(10))
            .background(cardBackground)

            HStack(spacing: S(9)) {
                Image(systemName: "waveform").foregroundStyle(theme.secondary)
                Picker("Chime sound", selection: $chimeSound) {
                    ForEach(FocusChimeController.availableSounds, id: \.self) { sound in
                        Text(sound).tag(sound)
                    }
                }
                .labelsHidden()
                .frame(width: S(105))
                Slider(value: $chimeVolume, in: 0.1...1.0)
                    .tint(theme.accent)
                Text("\(Int(chimeVolume * 100))%")
                    .font(.system(size: S(9), weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary).frame(width: S(34), alignment: .trailing)
                Button { FocusChimeController.shared.playPreview() } label: {
                    Image(systemName: "speaker.wave.3.fill").foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain).help("Play selected sound")
            }
            .padding(S(10))
            .background(cardBackground)

            HStack {
                Label("Pinned widget", systemImage: "pin.fill")
                    .font(.system(size: S(11), weight: .medium)).foregroundStyle(.secondary)
                Spacer()
                Picker("Pinned widget", selection: $pinnedMode) {
                    Text("Compact").tag("Compact")
                    Text("Money").tag("Money")
                }
                .labelsHidden()
                .frame(width: S(105))
                .onChange(of: pinnedMode) { _, newMode in
                    PinnedWindowController.shared.applyPreset(newMode)
                }
            }
            .padding(S(10))
            .background(cardBackground)

            HStack(spacing: S(10)) {
                Image(systemName: chimeEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .foregroundStyle(chimeEnabled ? theme.accent : .secondary)
                VStack(alignment: .leading, spacing: S(2)) {
                    Text("10-minute focus beep").font(.system(size: S(11), weight: .semibold))
                    if let remaining = FocusChimeController.shared.remaining(store: store, at: now) {
                        Text("Next in \(DurationText.compact(remaining))").font(.system(size: S(9))).foregroundStyle(.secondary)
                    } else {
                        Text(chimeEnabled ? "Starts while the timer is running" : "Optional \(chimeSound) sound at \(Int(chimeVolume * 100))%")
                            .font(.system(size: S(9))).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button { FocusChimeController.shared.playPreview() } label: {
                    Image(systemName: "play.circle").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain).help("Test sound")
                Toggle("", isOn: $chimeEnabled).labelsHidden().toggleStyle(.switch)
                    .onChange(of: chimeEnabled) { _, _ in FocusChimeController.shared.settingChanged() }
            }
            .padding(S(10))
            .background(cardBackground)

            Button(action: chooseCSV) {
                Label("Import timesheet CSV", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())

            Button { showPasteImporter = true } label: {
                Label("Paste approved timecards", systemImage: "doc.on.clipboard")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())

            if let message = store.statusMessage {
                Text(message).font(.system(size: S(10))).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("ALL  \(DurationText.compact(store.allDuration(at: now)))  •  \(store.allEarnings(at: now).money(code: store.currencyCode))")
                .font(.system(size: S(9), weight: .bold, design: .rounded))
                .foregroundStyle(.tertiary)
            Spacer()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
                .font(.system(size: S(10)))
                .foregroundStyle(.secondary)
        }
        .padding(.top, S(2))
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(.system(size: S(9), weight: .bold)).foregroundStyle(.secondary).tracking(S(1.2)).padding(.leading, S(2))
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: S(15), style: .continuous)
            .fill(theme.surface)
            .overlay(RoundedRectangle(cornerRadius: S(15)).stroke(theme.surfaceStroke))
    }

    private var statusColor: Color {
        guard let running = store.running else { return .secondary }
        return running.isPaused ? .orange : theme.accent
    }

    private var statusText: String {
        guard let running = store.running else { return "READY TO FOCUS" }
        return running.isPaused ? "PAUSED" : "FOCUS SESSION"
    }

    private var formattedRate: String { String(format: "%.2f", store.hourlyRate) }

    private func commitRate() {
        let normalized = rateText.replacingOccurrences(of: ",", with: ".")
        if let value = Double(normalized), value >= 0 {
            store.updateRate(value)
            rateText = String(format: "%.2f", value)
        } else {
            rateText = formattedRate
        }
    }

    private func chooseCSV() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.commaSeparatedText, .text]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let granted = url.startAccessingSecurityScopedResource()
            defer { if granted { url.stopAccessingSecurityScopedResource() } }
            csvPreviewSessions = try CSVImporter.parse(data: Data(contentsOf: url), hourlyRate: store.hourlyRate)
            showCSVComparison = true
        } catch {
            store.statusMessage = error.localizedDescription
        }
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    let accent: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label.padding(.vertical, S(12)).foregroundStyle(.black)
            .background(accent.opacity(configuration.isPressed ? 0.75 : 1), in: RoundedRectangle(cornerRadius: S(11)))
    }
}

private struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: S(12), weight: .semibold)).padding(.vertical, S(10))
            .background(.white.opacity(configuration.isPressed ? 0.1 : 0.06), in: RoundedRectangle(cornerRadius: S(10)))
            .overlay(RoundedRectangle(cornerRadius: S(10)).stroke(.white.opacity(0.08)))
    }
}

private struct DangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: S(12), weight: .semibold)).padding(.vertical, S(10))
            .foregroundStyle(.red.opacity(0.9))
            .background(.red.opacity(configuration.isPressed ? 0.18 : 0.1), in: RoundedRectangle(cornerRadius: S(10)))
    }
}
