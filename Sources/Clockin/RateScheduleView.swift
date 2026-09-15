import SwiftUI

struct RateScheduleView: View {
    @AppStorage(UIScale.key) private var uiScaleObserver = UIScale.defaultPercent
    @EnvironmentObject private var store: ClockStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("Clockin.Theme") private var themeRaw = ClockinThemeChoice.carbon.rawValue
    @State private var newDate = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1)) ?? .now
    @State private var newEndDate = Date()
    @State private var newHasEnd = false
    @State private var newRateText = ""

    private var theme: ClockinPalette { ClockinThemeChoice.selected(themeRaw).palette }

    var body: some View {
        VStack(alignment: .leading, spacing: S(14)) {
            HStack {
                VStack(alignment: .leading, spacing: S(3)) {
                    Text("Hourly rate schedule").font(.system(size: S(18), weight: .bold, design: theme.fontDesign))
                    Text("Open-ended rules can be combined with custom start–end periods.")
                        .font(.system(size: S(10))).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }.buttonStyle(.clockin(.primary))
            }

            Text("A bounded period overrides the fallback rate only between its dates. Sessions keep their historical rate calculation.")
                .font(.system(size: S(10))).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                .padding(S(10)).background(theme.surface, in: RoundedRectangle(cornerRadius: S(9)))

            ScrollView {
                VStack(spacing: S(8)) {
                    ForEach(store.rateRules) { rule in
                        RateRuleRow(rule: rule, canDelete: store.rateRules.count > 1)
                            .environmentObject(store)
                    }
                }
            }

            Divider().opacity(0.3)
            Text("Add rate period").font(ClockinFont.section).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: S(10)) {
                HStack {
                Text("From").font(ClockinFont.body)
                Spacer()
                DatePicker("From", selection: $newDate, displayedComponents: .date)
                    .labelsHidden().datePickerStyle(.field).controlSize(.large).frame(minHeight: S(32))
                }
                HStack {
                Toggle("Until", isOn: $newHasEnd).toggleStyle(.checkbox)
                Spacer()
                if newHasEnd {
                    DatePicker("Until", selection: $newEndDate, in: newDate..., displayedComponents: .date)
                        .labelsHidden().datePickerStyle(.field).controlSize(.large).frame(minHeight: S(32))
                }
                }
                HStack {
                ClockinTextField(placeholder: "Hourly rate", text: $newRateText, suffix: "/ hr", alignment: .leading)
                Button("Add") {
                    let normalized = newRateText.replacingOccurrences(of: ",", with: ".")
                    guard let value = Double(normalized), value >= 0 else { return }
                    store.addRateRule(effectiveFrom: newDate, effectiveUntil: newHasEnd ? newEndDate : nil, hourlyRate: value)
                    newRateText = ""
                }
                .buttonStyle(.clockin(.primary))
                }
            }
        }
        .padding(S(18))
        .frame(width: S(390), height: S(560))
        .scrollBounceBehavior(.basedOnSize)
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
        VStack(alignment: .leading, spacing: S(8)) {
            HStack {
                Text("From").font(ClockinFont.body)
                Spacer()
                DatePicker("From", selection: $date, displayedComponents: .date)
                    .labelsHidden().datePickerStyle(.field).controlSize(.large)
                    .onChange(of: date) { _, newDate in commit(date: newDate) }
            }
            HStack {
                Toggle("Until", isOn: $hasEnd).toggleStyle(.checkbox)
                    .onChange(of: hasEnd) { _, _ in commit(date: date) }
                Spacer()
                if hasEnd {
                    DatePicker("Until", selection: $endDate, in: date..., displayedComponents: .date)
                        .labelsHidden().datePickerStyle(.field).controlSize(.large)
                        .onChange(of: endDate) { _, _ in commit(date: date) }
                }
            }.frame(minHeight: S(32))
            HStack(spacing: S(10)) {
            ClockinTextField(placeholder: "Rate", text: $rateText, suffix: "/ hr", alignment: .leading)
                .onSubmit { commit(date: date) }
                .onChange(of: rateText) { _, newText in
                    let normalized = newText.replacingOccurrences(of: ",", with: ".")
                    guard let value = Double(normalized), value >= 0,
                          let stored = store.rateRules.first(where: { $0.id == rule.id }),
                          abs(value - stored.hourlyRate) > 0.000_001 else { return }
                    store.updateRateRule(id: rule.id, effectiveFrom: date, effectiveUntil: hasEnd ? endDate : nil, hourlyRate: value)
                }
            Button { store.deleteRateRule(id: rule.id) } label: {
                Image(systemName: "trash").foregroundStyle(canDelete ? .secondary : .tertiary)
            }
            .buttonStyle(.clockinIcon(destructive: true)).disabled(!canDelete)
            .help("Delete rate period").accessibilityLabel("Delete rate period")
            }
        }
        .padding(S(11))
        .background(theme.surface, in: RoundedRectangle(cornerRadius: S(10)))
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
