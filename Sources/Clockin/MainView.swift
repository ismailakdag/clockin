import AppKit
import SwiftUI

struct MainView: View {
    @AppStorage(UIScale.key) private var uiScaleObserver = UIScale.defaultPercent
    @EnvironmentObject private var store: ClockStore
    @EnvironmentObject private var exchangeRates: ExchangeRateStore
    @State private var now = Date()
    @State private var rateText = ""
    @State private var tab: MainTab = .dashboard
    @State private var showGuide = false
    @State private var showPasteImporter = false
    @State private var showCSVComparison = false
    @State private var csvPreviewSessions: [WorkSession] = []
    @State private var showManualStart = false
    @State private var showManualEntry = false
    @State private var editingSession: WorkSession?
    @State private var pendingDelete: WorkSession?
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
        var daily = store.dailyDurations
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
            Group {
                switch tab {
                case .dashboard:
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
                case .history:  HistoryView()
                case .heatmap:  HeatmapView()
                case .progress: ProgressDashboardView()
                case .settings: SettingsView().environmentObject(exchangeRates)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Burada bir capraz gecis denendi ama `.id(tab)` gerektiriyor,
            // o da her sekme degisiminde ekranin tamamini yikip yeniden
            // kuruyor. Heatmap ve Gecmis gibi agir ekranlarda bu, gecisin
            // tam ortasinda kare dusurmeye yol aciyor. Gostergenin kaymasi
            // degisimi zaten anlatiyor.
        }
        // Cubugu yigina koymak yerine ustune bindirir. `.ultraThinMaterial`
        // arkasindakini bulaniklastirdigi icin, icerigin altindan gecmesi
        // gerekiyor; yigin duzeninde arkada yalnizca duz zemin kaliyordu.
        // safeAreaInset ayrica kaydirilan icerige alt bosluk ekler, boylece
        // son satirlar cubugun altinda kalici olarak gizlenmez.
        .safeAreaInset(edge: .bottom, spacing: S(0)) {
            MainTabBar(selection: $tab, theme: theme)
        }
        // Pencerenin kok gorunumu. En kucuk olcu bildirilmezse NSHostingView
        // ideal boyutu sifir sanip pencereyi cokertiyor.
        .frame(minWidth: S(UIScale.base.width), maxWidth: .infinity,
               minHeight: S(UIScale.base.height), maxHeight: .infinity)
        // Icerik zaten sigiyorsa kaydirma esnemesin. Sabit duran bir
        // ekranin lastik gibi geri gelmesi bozukluk hissi veriyordu.
        // Bu degistirici alttaki kaydirma gorunumlerine yayilir.
        .scrollBounceBehavior(.basedOnSize)
        .background(theme.background)
        .fontDesign(theme.fontDesign)
        .clockinTextStyles()
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
        // Varsayilan bosluk olcekle buyumez; %130'da diger her sey buyurken
        // bu aralik sabit kalirdi.
        return HStack(spacing: S(8)) {
            ClockinLogo(size: 26)
            Spacer()
            levelChip(stats)
            HStack(spacing: S(2)) {
                // Gecmis, heatmap, progress ve ayarlar artik alt cubukta.
                headerIcon("questionmark.circle", help: "How to use Clockin") { showGuide = true }
                Button { store.setPinned(!store.pinVisible) } label: {
                    Image(systemName: store.pinVisible ? "pin.fill" : "pin")
                        .frame(width: S(28), height: S(28))
                }
                .buttonStyle(.clockinIcon(tint: store.pinVisible ? theme.accent : nil))
                .accessibilityLabel(store.pinVisible ? "Hide pinned timer" : "Pin timer to desktop")
                .help(store.pinVisible ? "Hide pinned timer" : "Pin timer to desktop")
            }
            .padding(S(3))
            .background(theme.surface, in: RoundedRectangle(cornerRadius: S(9), style: .continuous))
        }
        .padding(.horizontal, S(18))
        .frame(height: S(50))
        .background(theme.control)
        .overlay(alignment: .bottom) { Divider().opacity(0.25) }
    }

    /// Seviye rozeti.
    ///
    /// Once dugme grubunun kabinin icinde duz bir etiketti: ne dugmeydi ne de
    /// ayri bir oge, iki ikonun yanina sikismisti. Kendi kapsulune alindi ve
    /// dolgusu seviye icindeki ilerlemeyi gosteriyor, boylece yer kaplamasinin
    /// bir karsiligi oluyor.
    private func levelChip(_ stats: ProgressStats) -> some View {
        let span = 500
        let progress = min(max(Double(stats.xp % span) / Double(span), 0), 1)
        return Text("Level \(stats.level)")
            .font(.system(size: S(11), weight: .semibold).monospacedDigit())
            .foregroundStyle(theme.accent)
            .padding(.horizontal, S(10))
            .frame(height: S(26))
            // Never squeezed: a capsule narrower than its text showed cut ends.
            .fixedSize()
            .background {
                // The fill shows progress to the next level.
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(theme.accent.opacity(0.12))
                        Rectangle().fill(theme.accent.opacity(0.22)).frame(width: geo.size.width * progress)
                    }
                }
                .clipShape(PillShape())
                .overlay { PillShape().strokeBorder(theme.accent.opacity(0.28), lineWidth: 1) }

            }
        .help("Level \(stats.level) • \(stats.xp) XP • \(span - stats.xp % span) XP to next level")
    }

    private func headerIcon(_ systemName: String, color: Color = .secondary, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName).frame(width: S(28), height: S(28))
        }
        .buttonStyle(.clockinIcon(tint: color))
        .accessibilityLabel(help)
        .help(help)
    }

    private var timerCard: some View {
        VStack(spacing: S(17)) {
            HStack(spacing: S(7)) {
                Circle()
                    .fill(statusColor)
                    .frame(width: S(7), height: S(7))
                Text(statusText)
                    .font(.system(size: S(10), weight: .bold, design: theme.fontDesign))
                    .foregroundStyle(.secondary)

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
                Text("\((store.currentEarnings(at: now) * usdTry).money(code: "TRY"))")
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
        let perHour = store.currentRate(at: now)
        let current = store.currentEarnings(at: now)
        // Tam onlukta hedef bir sonraki onluga gecer; onceden hedef mevcut
        // tutara esit kalip "0 to go" derken cubuk bosaliyordu.
        let remainder = max(0, current).truncatingRemainder(dividingBy: 10)
        let milestone = max(0, current) + (10 - remainder)
        let progress = remainder / 10
        let isEarning = store.running?.isPaused == false
        return VStack(spacing: S(8)) {
            HStack(alignment: .firstTextBaseline, spacing: S(8)) {
                // The hourly rate, not fractions of a cent per second.
                Text(isEarning ? "Earning" : "Rate")
                    .font(ClockinFont.section).foregroundStyle(.secondary)
                Text("\(perHour.money(code: store.currencyCode))/h")
                    .font(.system(size: S(12), weight: .semibold).monospacedDigit())
                    .foregroundStyle(isEarning ? theme.accent : .secondary)
                if store.currencyCode == "USD", let usdTry = exchangeRates.latestRate {
                    Text("\((perHour * usdTry).money(code: "TRY"))/h")
                        .font(.system(size: S(11), weight: .medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: S(6))
                if store.running != nil {
                    // The bar already shows which milestone; this is the gap.
                    Text("\(max(0, milestone - current).money(code: store.currencyCode)) to go")
                        .font(.system(size: S(11), weight: .semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            if store.running != nil {
                ProgressView(value: progress)
                    .tint(theme.accent)
                    .scaleEffect(y: 0.65)
            }
        }
        .padding(S(10))
        .background(theme.control, in: RoundedRectangle(cornerRadius: S(10)))
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
                    .buttonStyle(.clockin(.secondary, size: .large, fullWidth: true))

                    Button {
                        completedSummary = store.clockOut()
                    } label: {
                        Label("Clock out", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.clockin(.primary, size: .large, fullWidth: true))
                }
                Button { confirmCancel = true } label: {
                    Label("Cancel session", systemImage: "xmark")
                        .font(.system(size: S(10), weight: .medium))
                }
                .buttonStyle(.clockin(.secondary, size: .small))
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
                .buttonStyle(.clockin(.primary, size: .large, fullWidth: true))
                VStack(spacing: S(7)) {
                    Button { showManualStart = true } label: {
                        Label("Start with elapsed time", systemImage: "clock.arrow.circlepath")
                            .font(.system(size: S(10), weight: .semibold))
                    }
                    .buttonStyle(.clockin(.secondary, size: .small, fullWidth: true))
                    Button { showManualEntry = true } label: {
                        Label("Add past entry", systemImage: "plus.circle")
                            .font(.system(size: S(10), weight: .semibold))
                    }
                    .buttonStyle(.clockin(.secondary, size: .small, fullWidth: true))
                }
            }
        }
    }

    private var todayCard: some View {
        VStack(spacing: S(12)) {
            HStack(spacing: S(0)) {
                metric(title: "Today", value: DurationText.compact(store.todayDuration(at: now)), icon: "clock")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Divider().frame(height: S(35)).opacity(0.25)
                todayEarnedMetric
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider().opacity(0.25).padding(.horizontal, S(14))
            // Work months start on the 1st, so the month's total earns a line
            // of its own next to today's.
            monthRow
        }
        .padding(.vertical, S(14))
        .background(cardBackground)
    }

    private var monthRow: some View {
        let earned = store.monthEarnings(at: now)
        let rate = exchangeRates.latestRate
        return HStack(spacing: S(0)) {
            metric(title: "Since the 1st", value: DurationText.compact(store.monthDuration(at: now)), icon: "calendar")
                .frame(maxWidth: .infinity, alignment: .leading)
            Divider().frame(height: S(35)).opacity(0.25)
            HStack(spacing: S(10)) {
                Image(systemName: "banknote")
                    .foregroundStyle(theme.accent.opacity(0.8))
                    .frame(width: S(20))
                VStack(alignment: .leading, spacing: S(3)) {
                    Text("Earned this month").font(ClockinFont.section).foregroundStyle(.secondary)
                    Text(earned.money(code: store.currencyCode))
                        .font(.system(size: S(14), weight: .semibold, design: .rounded)).lineLimit(1)
                    if store.currencyCode == "USD", let rate {
                        Text((earned * rate).money(code: "TRY"))
                            .font(.system(size: S(10), weight: .medium, design: .rounded))
                            .foregroundStyle(theme.accent)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, S(14))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var todayEarnedMetric: some View {
        let earned = store.todayEarnings(at: now)
        return HStack(spacing: S(10)) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .foregroundStyle(theme.accent.opacity(0.8))
                .frame(width: S(20))
            VStack(alignment: .leading, spacing: S(3)) {
                Text("Earned").font(ClockinFont.section).foregroundStyle(.secondary)
                Text(earned.money(code: store.currencyCode)).font(.system(size: S(13), weight: .semibold, design: .rounded))
                if store.currencyCode == "USD" {
                    if let rate = exchangeRates.latestRate {
                        Text((earned * rate).money(code: "TRY"))
                            .font(.system(size: S(10), weight: .medium, design: .rounded))
                            .foregroundStyle(theme.accent)
                    } else {
                        Text("TRY rate unavailable")
                            .font(.system(size: S(10), weight: .medium))
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
    }

    private var mascotCard: some View {
        return HStack(spacing: S(12)) {
            ClockinMascotStage().environmentObject(store).frame(width: S(62), height: S(62))
            Button { tab = .progress } label: {
                HStack(spacing: S(8)) {
                    VStack(alignment: .leading, spacing: S(4)) {
                        Text("Focus companion").font(ClockinFont.caption).foregroundStyle(Color.secondary)
                        Text(store.running?.isPaused == true ? "Session paused" : (store.running == nil ? "No active session" : "Session in progress"))
                            .font(.system(size: S(11), weight: .semibold)).foregroundStyle(Color.primary)
                        Text("See your streak and progress")
                            .font(.system(size: S(10))).foregroundStyle(theme.accent)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: S(10), weight: .semibold)).foregroundStyle(.secondary)
                }
                .padding(.vertical, S(8))
                .contentShape(Rectangle())
            }
            .buttonStyle(.clockin(.tinted, size: .small))
            .foregroundStyle(.primary)
            .accessibilityHint("Opens Progress")
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
                Text("USD / TRY").font(ClockinFont.section).foregroundStyle(.secondary)
                if let rate = exchangeRates.latestRate {
                    Text(String(format: "1 USD = %.3f TRY", rate)).font(.system(size: S(13), weight: .semibold, design: .rounded))
                    Text(rateStatusText).font(.system(size: S(10), weight: .medium)).foregroundStyle(rateStatusColor)
                } else {
                    Text(exchangeRates.isLoading ? "Fetching live rate…" : "Rate unavailable")
                        .font(.system(size: S(11), weight: .bold))
                        .foregroundStyle(exchangeRates.isLoading ? Color.secondary : Color.red)
                }
            }
            Spacer()
            if let day = exchangeRates.latestDate {
                Text(day).font(.system(size: S(10), design: .monospaced)).foregroundStyle(.secondary)
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
                Label("Goals", systemImage: "target").font(.system(size: S(10), weight: .bold)).foregroundStyle(.secondary)
                Spacer()
                if !hasGoals { Text("Set in Settings").font(.system(size: S(10))).foregroundStyle(.secondary) }
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
                Text("/ \(hoursText(goal))").font(.system(size: S(10))).foregroundStyle(.secondary)
            }
            ProgressView(value: progress).tint(progress >= 1 ? .green : theme.accent).scaleEffect(y: 0.7)
            Text(progress >= 1 ? "Goal reached" : "\(hoursText(max(0, goal - value))) remaining")
                .font(.system(size: S(10), weight: .medium)).foregroundStyle(progress >= 1 ? .green : .secondary)
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
                Text(title).font(.system(size: S(10), weight: .bold)).foregroundStyle(.secondary)
                Text(value).font(.system(size: S(14), weight: .semibold, design: .rounded)).lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, S(14))
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: S(10)) {
            HStack {
                sectionTitle("Recent sessions")
                Spacer()
                if !store.sessions.isEmpty {
                    Button("View all") { tab = .history }
                        .buttonStyle(.clockin(.ghost, size: .small)).font(.system(size: S(10), weight: .semibold)).foregroundStyle(theme.accent)
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
            Image(systemName: session.source == "Clockin" ? "clock" : "arrow.down.doc.fill")
                .font(.system(size: S(11)))
                .foregroundStyle(session.source == "Clockin" ? theme.accent : theme.secondary)
                .frame(width: S(28), height: S(28))
                .background(theme.control, in: RoundedRectangle(cornerRadius: S(8)))
            VStack(alignment: .leading, spacing: S(3)) {
                Text(session.start.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.system(size: S(12), weight: .medium))
                Text("\(session.start.formatted(date: .omitted, time: .shortened)) • \(session.note.isEmpty ? session.source : session.note)")
                    .font(.system(size: S(10)))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: S(3)) {
                Text(DurationText.compact(session.duration)).font(.system(size: S(12), weight: .semibold, design: .rounded))
                Text(store.earnings(for: session).money(code: store.currencyCode)).font(.system(size: S(10))).foregroundStyle(theme.accent)
            }
            // Bir kaydi duzeltmek ya da silmek icin Gecmis'e gitmek
            // gerekiyordu; en cok dokunulan kayitlar zaten burada duruyor.
            HStack(spacing: S(2)) {
                Button { editingSession = session } label: {
                    Image(systemName: "pencil").font(.system(size: S(10)))
                        .frame(width: S(22), height: S(22))
                }
                .buttonStyle(.clockinIcon(size: 28))
                .help("Edit times or note").accessibilityLabel("Edit times or note")
                Button { pendingDelete = session } label: {
                    Image(systemName: "trash").font(.system(size: S(10)))
                        .frame(width: S(22), height: S(22))
                }
                .buttonStyle(.clockinIcon(size: 28, destructive: true))
                .help("Delete this session").accessibilityLabel("Delete this session")
            }
        }
        .padding(.horizontal, S(12))
        .padding(.vertical, S(10))
    }

    private var footer: some View {
        HStack {
            Text("All time  \(DurationText.compact(store.allDuration(at: now)))  •  \(store.allEarnings(at: now).money(code: store.currencyCode))")
                .font(.system(size: S(10), weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
            Spacer()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.clockin(.ghost, size: .small))
                .font(.system(size: S(10)))
                .foregroundStyle(.secondary)
        }
        .padding(.top, S(2))
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(ClockinFont.section).foregroundStyle(.secondary).padding(.leading, S(2))
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: S(15), style: .continuous)
            .fill(theme.card)
            .overlay(RoundedRectangle(cornerRadius: S(15)).stroke(theme.cardStroke))
    }

    private var statusColor: Color {
        guard let running = store.running else { return .secondary }
        return running.isPaused ? .orange : theme.accent
    }

    private var statusText: String {
        guard let running = store.running else { return "No active session" }
        return running.isPaused ? "Paused" : "Focus session"
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
