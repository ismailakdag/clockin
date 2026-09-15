import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var store: ClockStore
    @EnvironmentObject private var exchangeRates: ExchangeRateStore
    @AppStorage("Clockin.Theme") private var themeRaw = ClockinThemeChoice.carbon.rawValue
    @AppStorage(UIScale.key) private var uiScale = UIScale.defaultPercent
    @AppStorage("Clockin.PinnedMode") private var pinnedMode = "Money"
    @AppStorage("Clockin.ChimeEnabled") private var chimeEnabled = false
    @AppStorage("Clockin.ChimeSound") private var chimeSound = "Glass"
    @AppStorage("Clockin.ChimeVolume") private var chimeVolume = 0.75
    @AppStorage("Clockin.ChimeIntervalMinutes") private var chimeInterval = 10
    @AppStorage("Clockin.MascotEnabled") private var mascotEnabled = true
    @AppStorage("Clockin.MascotDefault") private var mascotDefault = "Auto"
    @AppStorage("Clockin.MinimalMode") private var minimalMode = false
    @AppStorage("Clockin.MinimalShowHours") private var minimalShowHours = true
    @AppStorage("Clockin.MinimalShowEarnings") private var minimalShowEarnings = true
    @AppStorage("Clockin.MinimalShowTRY") private var minimalShowTRY = true
    @AppStorage("Clockin.MinimalShowGoal") private var minimalShowGoal = false
    @AppStorage("Clockin.MinimalShowSeconds") private var minimalShowSeconds = false
    @AppStorage("Clockin.GoalDailyHours") private var dailyGoalHours = 0.0
    @AppStorage("Clockin.GoalMonthlyHours") private var monthlyGoalHours = 0.0
    @State private var dailyGoalText = ""
    @State private var monthlyGoalText = ""
    @StateObject private var radio = RadioController.shared
    @State private var selectedStationID = "rp"
    @State private var rateText = ""
    @State private var showRateSchedule = false
    @State private var showPasteImporter = false
    @State private var showCSVComparison = false
    @State private var csvPreviewSessions: [WorkSession] = []
    @State private var confirmRestore = false
    @StateObject private var updates = UpdateChecker.shared

    private var theme: ClockinPalette { ClockinThemeChoice.selected(themeRaw).palette }

    var body: some View {
        VStack(spacing: S(0)) {
            ClockinScreenHeader(title: "Settings")
                .overlay(alignment: .bottom) { Rectangle().fill(theme.cardStroke).frame(height: 1) }
            ScrollView {
                VStack(alignment: .leading, spacing: S(20)) {
                    paySection
                    goalsSection
                    appearanceSection
                    menuBarSection
                    companionSection
                    chimeSection
                    radioSection
                    shortcutsSection
                    dataSection
                    updatesSection
                    Text("Settings are saved automatically.")
                        .font(ClockinFont.caption).foregroundStyle(.tertiary).frame(maxWidth: .infinity)
                }
                .padding(.horizontal, S(16))
                .padding(.vertical, S(16))
            }
        }
        .fontDesign(theme.fontDesign)
        .onAppear {
            rateText = String(format: "%.2f", store.hourlyRate)
            dailyGoalText = dailyGoalHours > 0 ? String(format: "%.2f", dailyGoalHours) : ""
            monthlyGoalText = monthlyGoalHours > 0 ? String(format: "%.2f", monthlyGoalHours) : ""
        }
        .onChange(of: rateText) { _, value in
            let normalized = value.replacingOccurrences(of: ",", with: ".")
            guard let number = Double(normalized), number >= 0,
                  abs(number - store.hourlyRate) > 0.000_001 else { return }
            store.updateRate(number)
        }
        .onChange(of: dailyGoalText) { _, value in dailyGoalHours = parsedGoal(value) }
        .onChange(of: monthlyGoalText) { _, value in monthlyGoalHours = parsedGoal(value) }
        .onChange(of: uiScale) { _, _ in MainWindowController.shared.applyScale() }
        .onChange(of: pinnedMode) { _, value in PinnedWindowController.shared.applyPreset(value) }
        .onChange(of: mascotDefault) { _, value in
            if let required = CompanionMode(rawValue: value)?.requiredHours, totalHours < required { mascotDefault = "Auto" }
        }
        .onChange(of: chimeEnabled) { _, _ in FocusChimeController.shared.settingChanged() }
        .onChange(of: chimeInterval) { _, _ in FocusChimeController.shared.settingChanged() }
        .onChange(of: minimalMode) { _, value in
            if value {
                UserDefaults.standard.set(store.pinVisible, forKey: "Clockin.PinVisibleBeforeMinimal")
            } else {
                let shouldRestorePin = UserDefaults.standard.object(forKey: "Clockin.PinVisibleBeforeMinimal") as? Bool ?? true
                UserDefaults.standard.removeObject(forKey: "Clockin.PinVisibleBeforeMinimal")
                NSApp.setActivationPolicy(.regular)
                MainWindowController.shared.show(store: store, exchangeRates: exchangeRates)
                store.setPinned(shouldRestorePin)
            }
        }
        .sheet(isPresented: $showRateSchedule) { RateScheduleView().environmentObject(store) }
        .sheet(isPresented: $showPasteImporter) { PasteImportView().environmentObject(store) }
        .sheet(isPresented: $showCSVComparison) {
            ImportComparisonView(sessions: csvPreviewSessions, sourceTitle: "Timesheet CSV") {
                showCSVComparison = false
            }
            .environmentObject(store)
        }
        .alert("Restore latest backup?", isPresented: $confirmRestore) {
            Button("Cancel", role: .cancel) {}
            Button("Restore", role: .destructive) { store.restoreLatestBackup() }
        } message: {
            Text("This replaces the current Clockin data with the newest automatic backup.")
        }
    }

    // MARK: Sections

    private var paySection: some View {
        ClockinSection(title: "Pay") {
            ClockinRow(icon: "dollarsign", title: "Hourly rate") {
                HStack(spacing: S(6)) {
                    ClockinTextField(placeholder: "0.00", text: $rateText, width: 84)
                    ClockinSelect(selection: Binding(get: { store.currencyCode }, set: { store.updateCurrency($0) }),
                                  values: ["USD", "EUR", "GBP", "TRY"], width: 82)
                }
            }
            ClockinRowDivider()
            ClockinRow(icon: "calendar.badge.clock", title: "Rate schedule",
                       subtitle: store.currentRateEffectiveFrom.map { "Current rate since \($0.formatted(.dateTime.month(.abbreviated).day().year()))" } ?? "Rates stored with each session") {
                Button("Manage") { showRateSchedule = true }
                    .buttonStyle(.clockin(.tinted, size: .small))
            }
        }
    }

    private var goalsSection: some View {
        ClockinSection(title: "Goals", footer: "Measured in worked hours and updated live while you are clocked in. Leave empty to turn a goal off.") {
            ClockinRow(icon: "sun.max", title: "Daily goal") {
                ClockinTextField(placeholder: "Off", text: $dailyGoalText, suffix: "h", width: 104)
            }
            ClockinRowDivider()
            ClockinRow(icon: "calendar", title: "Monthly goal") {
                ClockinTextField(placeholder: "Off", text: $monthlyGoalText, suffix: "h", width: 104)
            }
        }
    }

    private var appearanceSection: some View {
        ClockinSection(title: "Appearance") {
            VStack(alignment: .leading, spacing: S(10)) {
                HStack(spacing: S(11)) {
                    rowIcon("paintpalette")
                    VStack(alignment: .leading, spacing: S(2)) {
                        Text("Theme").font(ClockinFont.body)
                        Text("Colours and typeface for every Clockin window.").font(ClockinFont.caption).foregroundStyle(.secondary)
                    }
                }
                ClockinThemePicker(selection: $themeRaw)
            }
            .padding(S(13))
            ClockinRowDivider(inset: 13)
            VStack(alignment: .leading, spacing: S(10)) {
                HStack(spacing: S(11)) {
                    rowIcon("textformat.size")
                    VStack(alignment: .leading, spacing: S(2)) {
                        Text("Interface size").font(ClockinFont.body)
                        Text("Scales the whole window. Drag its edges for more room.").font(ClockinFont.caption).foregroundStyle(.secondary)
                    }
                }
                ClockinSegmented(selection: $uiScale, options: UIScale.options.map { ($0, UIScale.label(for: $0)) })
            }
            .padding(S(13))
        }
    }

    private var menuBarSection: some View {
        ClockinSection(title: "Menu bar & pinned timer") {
            ClockinRow(icon: "menubar.rectangle", title: "Minimal mode",
                       subtitle: "Hide the main window and pinned timer; keep everything in the menu bar.") {
                ClockinSwitch(isOn: $minimalMode)
            }
            if minimalMode {
                HStack {
                    Text("Ready when you are: this hides the main window.")
                        .font(ClockinFont.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Apply & hide") {
                        NSApp.setActivationPolicy(.accessory)
                        store.setPinned(false)
                        MainWindowController.shared.hide()
                    }
                    .buttonStyle(.clockin(.primary, size: .small))
                }
                .padding(.horizontal, S(13)).padding(.bottom, S(10))
            }
            ClockinRowDivider()
            VStack(alignment: .leading, spacing: S(9)) {
                VStack(alignment: .leading, spacing: S(2)) {
                    Text("Beside the menu bar icon").font(ClockinFont.body)
                    Text("Shown while you are clocked in. When you are not, only the icon shows.")
                        .font(ClockinFont.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: S(6)) {
                    ClockinChip(title: "Hours", isOn: $minimalShowHours)
                    ClockinChip(title: "Seconds", isOn: $minimalShowSeconds)
                        .disabled(!minimalShowHours)
                        .help("Only affects the running timer.")
                    ClockinChip(title: "Goal %", isOn: $minimalShowGoal)
                }
                HStack(spacing: S(6)) {
                    ClockinChip(title: "Earnings", isOn: $minimalShowEarnings)
                    ClockinChip(title: "Lira equivalent", isOn: $minimalShowTRY)
                }
            }
            .padding(.horizontal, S(13)).padding(.vertical, S(12))
            .padding(.leading, S(39))
            ClockinRowDivider()
            ClockinRow(icon: "pin", title: "Pinned timer", subtitle: "A small always-on-top timer.") {
                ClockinSwitch(isOn: Binding(get: { store.pinVisible }, set: { store.setPinned($0) }))
            }
            ClockinRowDivider()
            ClockinRow(icon: "rectangle.3.group", title: "Pinned timer layout") {
                ClockinSelect(selection: $pinnedMode, values: ["Compact", "Money", "Goal", "All", "Total"], width: 118)
            }
        }
    }

    private var companionSection: some View {
        ClockinSection(title: "Focus companion") {
            ClockinRow(icon: "figure.wave", title: "Show companion", subtitle: "The mascot on the timer, progress and menu bar panel.") {
                ClockinSwitch(isOn: $mascotEnabled)
            }
            ClockinRowDivider()
            ClockinRow(icon: "sparkles", title: "Behaviour", subtitle: "More poses unlock as your hours add up.") {
                ClockinSelect(selection: $mascotDefault, options: CompanionMode.allCases.map { mode in
                    let locked = !mode.isUnlocked(totalHours: totalHours)
                    return .init(value: mode.rawValue,
                                 label: locked ? "\(mode.rawValue) · \(Int(mode.requiredHours))h" : mode.rawValue,
                                 systemImage: locked ? "lock.fill" : nil,
                                 disabled: locked)
                }, width: 124)
            }
        }
    }

    private var chimeSection: some View {
        ClockinSection(title: "Focus chime") {
            ClockinRow(icon: chimeEnabled ? "bell.badge" : "bell.slash", title: "Chime while clocked in") {
                ClockinSwitch(isOn: $chimeEnabled)
            }
            ClockinRowDivider()
            ClockinRow(icon: "timer", title: "Every") {
                ClockinStepper(value: $chimeInterval, range: 1...120, format: { "\($0) min" })
            }
            ClockinRowDivider()
            ClockinRow(icon: "music.note", title: "Sound") {
                HStack(spacing: S(6)) {
                    ClockinSelect(selection: $chimeSound, values: FocusChimeController.availableSounds, width: 118)
                    Button { FocusChimeController.shared.playPreview() } label: { Image(systemName: "play.fill") }
                        .buttonStyle(.clockinIcon(size: 32, tint: theme.accent))
                        .help("Play the chime")
                        .accessibilityLabel("Play the chime")
                }
            }
            ClockinRowDivider()
            volumeRow(value: $chimeVolume, range: 0.1...1)
        }
    }

    private var radioSection: some View {
        ClockinSection(title: "Focus radio", footer: selectedStation.map { "\($0.description). Streams over the internet." }) {
            VStack(spacing: S(10)) {
                HStack(spacing: S(8)) {
                    rowIcon(radio.isPlaying ? "dot.radiowaves.left.and.right" : "radio")
                    ClockinSelect(selection: $selectedStationID, options: radio.stations.map {
                        .init(value: $0.id, label: "\($0.name) · \($0.language)")
                    }, width: .infinity)
                    Button {
                        if let station = selectedStation { radio.toggle(station: station) }
                    } label: {
                        Label(radio.isPlaying ? "Stop" : "Play", systemImage: radio.isPlaying ? "stop.fill" : "play.fill")
                    }
                    .buttonStyle(.clockin(.primary))
                }
                if let error = radio.errorMessage {
                    Text(error).font(ClockinFont.caption).foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(S(13))
            ClockinRowDivider()
            volumeRow(value: $radio.volume, range: 0...1)
        }
    }

    private var shortcutsSection: some View {
        ClockinSection(title: "Keyboard shortcuts", footer: "Work while Clockin is running. macOS may ask for accessibility permission to use them in other apps.") {
            shortcutRow(["⌥", "⌘", "I"], "Clock in or resume", icon: "play")
            ClockinRowDivider()
            shortcutRow(["⌥", "⌘", "P"], "Pause or resume", icon: "pause")
            ClockinRowDivider()
            shortcutRow(["⌥", "⌘", "O"], "Clock out", icon: "stop")
            ClockinRowDivider()
            shortcutRow(["⌥", "⌘", "E"], "Open the Clockin window", icon: "macwindow")
        }
    }

    private var dataSection: some View {
        ClockinSection(title: "Data") {
            VStack(spacing: S(8)) {
                HStack(spacing: S(8)) {
                    Button(action: chooseCSV) { Label("Import CSV", systemImage: "square.and.arrow.down") }
                        .buttonStyle(.clockin(.secondary, fullWidth: true))
                    Button { showPasteImporter = true } label: { Label("Paste timecards", systemImage: "doc.on.clipboard") }
                        .buttonStyle(.clockin(.secondary, fullWidth: true))
                }
                HStack(spacing: S(8)) {
                    Button(action: exportBackup) { Label("Export backup", systemImage: "square.and.arrow.up") }
                        .buttonStyle(.clockin(.secondary, fullWidth: true))
                    Button(action: importBackup) { Label("Restore file", systemImage: "arrow.down.doc") }
                        .buttonStyle(.clockin(.secondary, fullWidth: true))
                }
            }
            .padding(S(13))
            ClockinRowDivider(inset: 13)
            ClockinRow(icon: "clock.arrow.circlepath", title: "Automatic backups",
                       subtitle: store.latestBackupDate.map { "Last \($0.formatted(.dateTime.month(.abbreviated).day().hour().minute())) · \(store.backupCount) kept" } ?? "Made automatically, at most once a day") {
                Button("Restore latest") { confirmRestore = true }
                    .buttonStyle(.clockin(.tinted, size: .small))
                    .disabled(store.latestBackupDate == nil)
            }
            if let message = store.statusMessage {
                Text(message).font(ClockinFont.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, S(13)).padding(.bottom, S(12))
            }
        }
    }

    private var updatesSection: some View {
        ClockinSection(title: "Updates") {
            ClockinRow(icon: "shippingbox", title: "Clockin \(updates.version)", subtitle: updateStatusText) {
                Button(updates.pendingVersion == nil ? "Check now" : "Install update") { updates.checkForUpdates() }
                    .buttonStyle(.clockin(updates.pendingVersion == nil ? .tinted : .primary, size: .small))
                    .disabled(!updates.isReady)
            }
            ClockinRowDivider()
            ClockinRow(icon: "arrow.clockwise", title: "Check automatically", subtitle: "Every six hours.") {
                ClockinSwitch(isOn: Binding(
                    get: { updates.automaticallyChecksForUpdates },
                    set: { updates.setAutomaticallyChecksForUpdates($0) }
                ))
            }
        }
    }

    // MARK: Pieces

    private var updateStatusText: String {
        if let error = updates.startupError { return "Updates unavailable: \(error)" }
        if let version = updates.pendingVersion { return "Clockin \(version) is available." }
        if let checked = updates.lastChecked {
            return "Last checked \(checked.formatted(date: .abbreviated, time: .shortened))"
        }
        return "New versions download and install here."
    }

    private var selectedStation: RadioController.Station? {
        radio.stations.first { $0.id == selectedStationID }
    }

    private func rowIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: S(12), weight: .semibold))
            .foregroundStyle(theme.accent)
            .frame(width: S(28), height: S(28))
            .background(theme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: S(8), style: .continuous))
    }

    private func volumeRow(value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack(spacing: S(11)) {
            rowIcon("speaker.wave.2")
            Text("Volume").font(ClockinFont.body)
            Slider(value: value, in: range).tint(theme.accent).controlSize(.regular)
            Text("\(Int(value.wrappedValue * 100))%")
                .font(.system(size: S(11.5), weight: .semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: S(38), alignment: .trailing)
        }
        .padding(.horizontal, S(13)).frame(minHeight: S(50))
    }

    private func shortcutRow(_ keys: [String], _ title: String, icon: String) -> some View {
        ClockinRow(icon: icon, title: title) {
            HStack(spacing: S(3)) {
                ForEach(keys, id: \.self) { key in
                    Text(key)
                        .font(.system(size: S(11), weight: .semibold, design: .rounded))
                        .frame(minWidth: S(22), minHeight: S(22))
                        .background(theme.control, in: RoundedRectangle(cornerRadius: S(5), style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: S(5), style: .continuous).strokeBorder(theme.controlStroke, lineWidth: 1))
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(keys.joined(separator: " "))
        }
    }

    private func parsedGoal(_ text: String) -> Double {
        max(0, Double(text.replacingOccurrences(of: ",", with: ".")) ?? 0)
    }

    private var totalHours: Double { (store.totalDuration + store.elapsed()) / 3600 }
    private func chooseCSV() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.commaSeparatedText, .text]
        panel.allowsMultipleSelection = false; panel.canChooseDirectories = false
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

    private func exportBackup() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "clockin-backup.json"
        if panel.runModal() == .OK, let url = panel.url { store.exportBackup(to: url) }
    }

    private func importBackup() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url { store.importBackup(from: url) }
    }
}
