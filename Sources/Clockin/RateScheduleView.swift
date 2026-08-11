import SwiftUI

struct RateScheduleView: View {
    @EnvironmentObject private var store: ClockStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("Clockin.Theme") private var themeRaw = ClockinThemeChoice.carbon.rawValue
    @State private var newDate = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1)) ?? .now
    @State private var newEndDate = Date()
    @State private var newHasEnd = false
    @State private var newRateText = ""

    private var theme: ClockinPalette { ClockinThemeChoice.selected(themeRaw).palette }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Hourly rate schedule").font(.system(size: 18, weight: .bold, design: theme.fontDesign))
                    Text("Open-ended rules can be combined with custom start–end periods.")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }.buttonStyle(ClockinAccentButtonStyle(palette: theme))
            }

            Text("A bounded period overrides the fallback rate only between its dates. Sessions keep their historical rate calculation.")
                .font(.system(size: 9)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                .padding(10).background(theme.surface, in: RoundedRectangle(cornerRadius: 9))

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(store.rateRules) { rule in
                        RateRuleRow(rule: rule, canDelete: store.rateRules.count > 1)
                            .environmentObject(store)
                    }
                }
            }

            Divider().opacity(0.3)
            Text("ADD RATE PERIOD").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary).tracking(1)
            HStack(spacing: 7) {
                DatePicker("From", selection: $newDate, displayedComponents: .date)
                    .labelsHidden().controlSize(.small).font(.system(size: 9, design: .monospaced)).frame(width: 92)
                Toggle("Until", isOn: $newHasEnd).toggleStyle(.checkbox).controlSize(.small)
                if newHasEnd {
                    DatePicker("", selection: $newEndDate, in: newDate..., displayedComponents: .date)
                        .labelsHidden().controlSize(.small).font(.system(size: 9, design: .monospaced)).frame(width: 92)
                }
                TextField("Hourly rate", text: $newRateText)
                    .textFieldStyle(.plain).font(.system(size: 11, design: .monospaced)).padding(7).frame(width: 85)
                    .background(theme.surface, in: RoundedRectangle(cornerRadius: 8))
                Button("Add") {
                    let normalized = newRateText.replacingOccurrences(of: ",", with: ".")
                    guard let value = Double(normalized), value >= 0 else { return }
                    store.addRateRule(effectiveFrom: newDate, effectiveUntil: newHasEnd ? newEndDate : nil, hourlyRate: value)
                    newRateText = ""
                }
                .buttonStyle(ClockinAccentButtonStyle(palette: theme))
            }
        }
        .padding(18)
        .frame(width: 560, height: 520)
        .background(theme.background)
        .fontDesign(theme.fontDesign)
        .preferredColorScheme(theme.colorScheme)
    }
}

private struct RateRuleRow: View {
    @EnvironmentObject private var store: ClockStore
    @AppStorage("Clockin.Theme") private var themeRaw = ClockinThemeChoice.carbon.rawValue
    let rule: RateRule
    let canDelete: Bool
    @State private var date: Date
    @State private var endDate: Date
    @State private var hasEnd: Bool
    @State private var rateText: String

    private var theme: ClockinPalette { ClockinThemeChoice.selected(themeRaw).palette }

    init(rule: RateRule, canDelete: Bool) {
        self.rule = rule
        self.canDelete = canDelete
        _date = State(initialValue: rule.effectiveFrom)
        _endDate = State(initialValue: rule.effectiveUntil ?? rule.effectiveFrom)
        _hasEnd = State(initialValue: rule.effectiveUntil != nil)
        _rateText = State(initialValue: String(format: "%.2f", rule.hourlyRate))
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar.badge.clock").foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text("FROM").font(.system(size: 7, weight: .bold)).foregroundStyle(.tertiary)
                    DatePicker("", selection: $date, displayedComponents: .date)
                        .labelsHidden().controlSize(.small).font(.system(size: 9, design: .monospaced)).frame(width: 92)
                        .onChange(of: date) { _, newDate in commit(date: newDate) }
                    Toggle("Until", isOn: $hasEnd).toggleStyle(.checkbox).controlSize(.small)
                        .onChange(of: hasEnd) { _, _ in commit(date: date) }
                    if hasEnd {
                        DatePicker("", selection: $endDate, in: date..., displayedComponents: .date)
                            .labelsHidden().controlSize(.small).font(.system(size: 9, design: .monospaced)).frame(width: 92)
                            .onChange(of: endDate) { _, _ in commit(date: date) }
                    }
                }
            }
            Spacer(minLength: 4)
            TextField("Rate", text: $rateText)
                .textFieldStyle(.plain).font(.system(size: 11, design: .monospaced)).multilineTextAlignment(.trailing).frame(width: 65)
                .onSubmit { commit(date: date) }
                .onChange(of: rateText) { _, newText in
                    let normalized = newText.replacingOccurrences(of: ",", with: ".")
                    guard let value = Double(normalized), value >= 0,
                          let stored = store.rateRules.first(where: { $0.id == rule.id }),
                          abs(value - stored.hourlyRate) > 0.000_001 else { return }
                    store.updateRateRule(id: rule.id, effectiveFrom: date, effectiveUntil: hasEnd ? endDate : nil, hourlyRate: value)
                }
            Text("/ hr").font(.system(size: 10)).foregroundStyle(.secondary)
            Button { store.deleteRateRule(id: rule.id) } label: {
                Image(systemName: "trash").foregroundStyle(canDelete ? .secondary : .tertiary)
            }
            .buttonStyle(.plain).disabled(!canDelete)
        }
        .padding(11)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 10))
    }

    private func commit(date: Date) {
        let normalized = rateText.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value >= 0 else {
            rateText = String(format: "%.2f", rule.hourlyRate)
            return
        }
        store.updateRateRule(id: rule.id, effectiveFrom: date, effectiveUntil: hasEnd ? endDate : nil, hourlyRate: value)
        rateText = String(format: "%.2f", value)
    }
}
