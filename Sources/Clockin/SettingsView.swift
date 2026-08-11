import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var store: ClockStore
    @EnvironmentObject private var exchangeRates: ExchangeRateStore
    @AppStorage("Clockin.Theme") private var themeRaw = ClockinThemeChoice.carbon.rawValue
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
    let onBack: () -> Void

    private var theme: ClockinPalette { ClockinThemeChoice.selected(themeRaw).palette }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    section("PAY & CURRENCY", content: paySection)
                    section("EARNINGS GOALS", content: goalsSection)
                    section("APPEARANCE", content: appearanceSection)
                    section("FOCUS CHIME", content: chimeSection)
                    section("KEYBOARD SHORTCUTS", content: shortcutsSection)
                    section("FOCUS RADIO", content: radioSection)
                    section("DATA", content: dataSection)
                    Text("Settings are saved automatically.")
                        .font(.system(size: 9)).foregroundStyle(.tertiary).frame(maxWidth: .infinity)
                }
                .padding(16)
            }
        }
        .fontDesign(theme.fontDesign)
        .onAppear {
            rateText = String(format: "%.2f", store.hourlyRate)
            dailyGoalText = dailyGoalHours > 0 ? String(format: "%.2f", dailyGoalHours) : ""
            monthlyGoalText = monthlyGoalHours > 0 ? String(format: "%.2f", monthlyGoalHours) : ""
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

    private var header: some View {
        HStack {
            Button(action: onBack) { Image(systemName: "chevron.left").frame(width: 26, height: 26) }.buttonStyle(.plain)
            Text("SETTINGS").font(.system(size: 13, weight: .black, design: theme.fontDesign)).tracking(1.3)
            Spacer()
        }
        .padding(.horizontal, 15).frame(height: 50)
        .background(.white.opacity(0.025))
        .overlay(alignment: .bottom) { Divider().opacity(0.25) }
    }

    private var paySection: some View {
        VStack(spacing: 9) {
            HStack {
                Label("Hourly rate", systemImage: "dollarsign.circle.fill").foregroundStyle(.secondary)
                Spacer()
                TextField("Rate", text: $rateText)
                    .textFieldStyle(.plain).multilineTextAlignment(.trailing).frame(width: 72)
                    .onChange(of: rateText) { _, value in
                        let normalized = value.replacingOccurrences(of: ",", with: ".")
                        guard let number = Double(normalized), number >= 0,
                              abs(number - store.hourlyRate) > 0.000_001 else { return }
                        store.updateRate(number)
                    }
                Picker("", selection: Binding(get: { store.currencyCode }, set: { value in store.updateCurrency(value) })) {
                    ForEach(["USD", "EUR", "GBP", "TRY"], id: \.self) { Text($0).tag($0) }
                }.labelsHidden().frame(width: 82)
            }.padding(10).background(card)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("RATE SCHEDULE").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary).tracking(1)
                    Text(store.currentRateEffectiveFrom?.formatted(.dateTime.month(.abbreviated).day().year()) ?? "Stored session rates")
                        .font(.system(size: 9)).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Manage") { showRateSchedule = true }.buttonStyle(.plain).foregroundStyle(theme.accent)
            }.padding(10).background(card)
        }
    }

    private var appearanceSection: some View {
        VStack(spacing: 9) {
            HStack {
                Label("Theme & font", systemImage: "paintpalette.fill").foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: $themeRaw) {
                    ForEach(ClockinThemeChoice.allCases) { Text($0.rawValue).tag($0.rawValue) }
                }.labelsHidden().frame(width: 140)
            }.padding(10).background(card)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Minimal menu bar mode", systemImage: "menubar.rectangle")
                        .foregroundStyle(.secondary)
                    Text("Hide the main window and pinned widget; keep controls in the menu bar.")
                        .font(.system(size: 8)).foregroundStyle(.tertiary)
                }
                Spacer()
                Toggle("", isOn: $minimalMode)
                    .labelsHidden().toggleStyle(.switch)
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
            }.padding(10).background(card)
            if minimalMode {
                HStack {
                    Text("Minimal mode is configured. Apply it when you are ready to hide this window.")
                        .font(.system(size: 8)).foregroundStyle(.tertiary)
                    Spacer()
                    Button("Apply & hide") {
                        NSApp.setActivationPolicy(.accessory)
                        store.setPinned(false)
                        MainWindowController.shared.hide()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.accent)
                }
                .padding(.horizontal, 10)
            }
            VStack(alignment: .leading, spacing: 8) {
                Label("Minimal status fields", systemImage: "text.badge.checkmark")
                    .foregroundStyle(.secondary)
                Text("Choose what appears beside the menu-bar icon while minimal mode is active.")
                    .font(.system(size: 8)).foregroundStyle(.tertiary)
                HStack(spacing: 12) {
                    Toggle("Hours", isOn: $minimalShowHours)
                    Toggle("Earnings", isOn: $minimalShowEarnings)
                }
                HStack(spacing: 12) {
                    Toggle("TL equivalent", isOn: $minimalShowTRY)
                    Toggle("Goal %", isOn: $minimalShowGoal)
                }
            }
            .font(.system(size: 9, weight: .medium))
            .toggleStyle(.checkbox)
            .padding(10).background(card)
            HStack {
                Label("Pinned widget", systemImage: "pin.fill").foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: $pinnedMode) {
                    Text("Compact").tag("Compact"); Text("Money").tag("Money"); Text("Goal").tag("Goal"); Text("All").tag("All")
                }.labelsHidden().frame(width: 110)
                    .onChange(of: pinnedMode) { _, value in PinnedWindowController.shared.applyPreset(value) }
                Toggle("", isOn: Binding(
                    get: { store.pinVisible },
                    set: { value in store.setPinned(value) }
                )).labelsHidden().toggleStyle(.switch)
            }.padding(10).background(card)
            HStack {
                Label("Progress mascot", systemImage: "figure.wave.circle.fill").foregroundStyle(.secondary)
                Spacer()
                Toggle("", isOn: $mascotEnabled).labelsHidden().toggleStyle(.switch)
            }.padding(10).background(card)
            HStack {
                Label("Default behavior", systemImage: "sparkles").foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: $mascotDefault) {
                    ForEach(mascotOptions, id: \.0) { option in
                        Text(option.2 > totalHours ? "🔒 \(option.1)" : option.1).tag(option.0)
                    }
                }.labelsHidden().frame(width: 120)
                    .onChange(of: mascotDefault) { _, value in
                        if let required = mascotOptions.first(where: { $0.0 == value })?.2, totalHours < required { mascotDefault = "Auto" }
                    }
            }.padding(10).background(card)
        }
    }

    private var goalsSection: some View {
        VStack(spacing: 9) {
            goalField("Daily hours", icon: "sun.max.fill", text: $dailyGoalText) { dailyGoalHours = parsedGoal(dailyGoalText) }
            goalField("Monthly hours", icon: "calendar", text: $monthlyGoalText) { monthlyGoalHours = parsedGoal(monthlyGoalText) }
            Text("Goals are measured in worked hours and update live while clocked in.")
                .font(.system(size: 9)).foregroundStyle(.tertiary)
        }
    }

    private func goalField(_ title: String, icon: String, text: Binding<String>, commit: @escaping () -> Void) -> some View {
        HStack {
            Label(title, systemImage: icon).foregroundStyle(.secondary)
            Spacer()
            TextField("Off", text: text)
                .textFieldStyle(.plain).multilineTextAlignment(.trailing).frame(width: 90)
                .onChange(of: text.wrappedValue) { _, _ in commit() }
            Text("hours").font(.system(size: 9, weight: .bold)).foregroundStyle(theme.accent)
        }.padding(10).background(card)
    }

    private func parsedGoal(_ text: String) -> Double {
        max(0, Double(text.replacingOccurrences(of: ",", with: ".")) ?? 0)
    }

    private var chimeSection: some View {
        VStack(spacing: 9) {
            HStack {
                Label("Focus chime", systemImage: chimeEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .foregroundStyle(chimeEnabled ? theme.accent : .secondary)
                Spacer()
                Toggle("", isOn: $chimeEnabled).labelsHidden().toggleStyle(.switch)
                    .onChange(of: chimeEnabled) { _, _ in FocusChimeController.shared.settingChanged() }
            }.padding(10).background(card)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("INTERVAL").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary).tracking(1)
                    Text("Every \(chimeInterval) minute\(chimeInterval == 1 ? "" : "s")")
                        .font(.system(size: 11, weight: .semibold))
                }
                Spacer()
                Stepper("", value: $chimeInterval, in: 1...120).labelsHidden()
                    .onChange(of: chimeInterval) { _, _ in FocusChimeController.shared.settingChanged() }
            }.padding(10).background(card)
            HStack(spacing: 8) {
                Picker("", selection: $chimeSound) {
                    ForEach(FocusChimeController.availableSounds, id: \.self) { Text($0).tag($0) }
                }.labelsHidden().frame(width: 105)
                Slider(value: $chimeVolume, in: 0.1...1).tint(theme.accent)
                Text("\(Int(chimeVolume * 100))%").font(.system(size: 9, design: .monospaced)).frame(width: 34)
                Button { FocusChimeController.shared.playPreview() } label: { Image(systemName: "play.circle.fill") }
                    .buttonStyle(.plain).foregroundStyle(theme.accent).help("Test sound")
            }.padding(10).background(card)
        }
    }

    private var dataSection: some View {
        VStack(spacing: 9) {
            Button(action: chooseCSV) { Label("Import timesheet CSV", systemImage: "square.and.arrow.down").frame(maxWidth: .infinity) }
                .buttonStyle(.bordered)
            Button { showPasteImporter = true } label: { Label("Paste approved timecards", systemImage: "doc.on.clipboard").frame(maxWidth: .infinity) }
                .buttonStyle(.bordered)
            HStack(spacing: 9) {
                Button(action: exportBackup) {
                    Label("Export backup", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                }.buttonStyle(.bordered)
                Button(action: importBackup) {
                    Label("Restore file", systemImage: "arrow.down.doc").frame(maxWidth: .infinity)
                }.buttonStyle(.bordered)
            }
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("AUTOMATIC BACKUPS").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary).tracking(1)
                    Text(store.latestBackupDate.map { "Last \($0.formatted(.dateTime.month(.abbreviated).day().hour().minute())) • \(store.backupCount) saved" } ?? "Created automatically before each save")
                        .font(.system(size: 9)).foregroundStyle(.tertiary)
                }
                Spacer()
                Button("Restore latest") { confirmRestore = true }
                    .buttonStyle(.plain).foregroundStyle(theme.accent)
                    .disabled(store.latestBackupDate == nil)
            }.padding(10).background(card)
            if let message = store.statusMessage { Text(message).font(.system(size: 9)).foregroundStyle(.secondary) }
        }
    }

    private var shortcutsSection: some View {
        VStack(spacing: 7) {
            shortcutRow("⌥⌘I", "Clock in / resume", icon: "play.fill")
            shortcutRow("⌥⌘P", "Pause / resume", icon: "pause.fill")
            shortcutRow("⌥⌘O", "Clock out", icon: "stop.fill")
            shortcutRow("⌥⌘E", "Open Clockin window", icon: "macwindow")
            Text("Works while Clockin is running. macOS may ask for accessibility permission for use while another app is focused.")
                .font(.system(size: 8)).foregroundStyle(.tertiary)
        }
    }

    private func shortcutRow(_ shortcut: String, _ title: String, icon: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon).frame(width: 17).foregroundStyle(theme.accent)
            Text(title).font(.system(size: 10, weight: .medium))
            Spacer()
            Text(shortcut).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(.secondary)
        }.padding(9).background(card)
    }

    private var radioSection: some View {
        VStack(spacing: 9) {
            HStack(spacing: 10) {
                Image(systemName: radio.isPlaying ? "dot.radiowaves.left.and.right" : "radio")
                    .foregroundStyle(radio.isPlaying ? theme.accent : .secondary)
                Picker("Station", selection: $selectedStationID) {
                    ForEach(radio.stations) { station in
                        Text("[\(station.language)] \(station.name)").tag(station.id).help(station.description)
                    }
                }.labelsHidden().frame(maxWidth: .infinity)
                Spacer()
                Button(radio.isPlaying ? "Stop" : "Play") {
                    if let station = radio.stations.first(where: { $0.id == selectedStationID }) { radio.toggle(station: station) }
                }
                    .buttonStyle(.borderedProminent).tint(theme.accent)
            }.padding(10).background(card)
            HStack(spacing: 8) {
                Image(systemName: "speaker.wave.2.fill").foregroundStyle(theme.accent)
                Text("Volume").font(.system(size: 10, weight: .semibold))
                Slider(value: $radio.volume, in: 0...1).tint(theme.accent)
                Text("\(Int(radio.volume * 100))%").font(.system(size: 9, design: .monospaced)).frame(width: 32)
            }.padding(10).background(card)
            if let station = radio.stations.first(where: { $0.id == selectedStationID }) {
                Text(station.description).font(.system(size: 8)).foregroundStyle(.tertiary).frame(maxWidth: .infinity, alignment: .leading)
            }
            Text("Radio streams over the internet and may use data. Hover a channel for details.")
                .font(.system(size: 8)).foregroundStyle(.tertiary)
        }
    }

    private func section<Content: View>(_ title: String, content: Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary).tracking(1.2)
            content
        }
    }

    private var card: some View {
        RoundedRectangle(cornerRadius: 11).fill(theme.surface)
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(theme.surfaceStroke))
    }

    private var totalHours: Double { (store.totalDuration + store.elapsed()) / 3600 }
    private var mascotOptions: [(String, String, Double)] {
        [("Auto", "Auto", 0), ("Typing", "Typing", 0), ("Coffee", "Coffee", 0), ("Victory", "Victory • 10h", 10), ("Stretch", "Stretch • 25h", 25), ("Dance", "Dance • 50h", 50), ("Music", "Music • 100h", 100)]
    }

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
