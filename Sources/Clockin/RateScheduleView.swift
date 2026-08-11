import SwiftUI

struct RateScheduleView: View {
    @EnvironmentObject private var store: ClockStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("Clockin.Theme") private var themeRaw = ClockinThemeChoice.carbon.rawValue
    @State private var newDate = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1)) ?? .now
    @State private var newRateText = ""

    private var theme: ClockinPalette { ClockinThemeChoice.selected(themeRaw).palette }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Hourly rate schedule").font(.system(size: 18, weight: .bold, design: theme.fontDesign))
                    Text("Each rule applies until the next effective date.")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }.buttonStyle(.borderedProminent).tint(theme.accent).foregroundStyle(.black)
            }

            Text("Sessions before the first rule keep the rate stored when they were imported or clocked. Add an earlier rule to override them.")
                .font(.system(size: 10)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                .padding(10).background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 9))

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
            HStack {
                DatePicker("", selection: $newDate, displayedComponents: .date).labelsHidden()
                TextField("Hourly rate", text: $newRateText)
                    .textFieldStyle(.plain).padding(8).frame(width: 105)
                    .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                Button("Add") {
                    let normalized = newRateText.replacingOccurrences(of: ",", with: ".")
                    guard let value = Double(normalized), value >= 0 else { return }
                    store.addRateRule(effectiveFrom: newDate, hourlyRate: value)
                    newRateText = ""
                }
                .buttonStyle(.borderedProminent).tint(theme.accent).foregroundStyle(.black)
            }
        }
        .padding(18)
        .frame(width: 510, height: 480)
        .background(theme.background)
        .fontDesign(theme.fontDesign)
        .preferredColorScheme(.dark)
    }
}

private struct RateRuleRow: View {
    @EnvironmentObject private var store: ClockStore
    let rule: RateRule
    let canDelete: Bool
    @State private var date: Date
    @State private var rateText: String

    init(rule: RateRule, canDelete: Bool) {
        self.rule = rule
        self.canDelete = canDelete
        _date = State(initialValue: rule.effectiveFrom)
        _rateText = State(initialValue: String(format: "%.2f", rule.hourlyRate))
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar.badge.clock").foregroundStyle(.secondary)
            DatePicker("", selection: $date, displayedComponents: .date)
                .labelsHidden()
                .onChange(of: date) { _, newDate in commit(date: newDate) }
            Spacer()
            TextField("Rate", text: $rateText)
                .textFieldStyle(.plain).multilineTextAlignment(.trailing).frame(width: 70)
                .onSubmit { commit(date: date) }
                .onChange(of: rateText) { _, newText in
                    let normalized = newText.replacingOccurrences(of: ",", with: ".")
                    guard let value = Double(normalized), value >= 0,
                          let stored = store.rateRules.first(where: { $0.id == rule.id }),
                          abs(value - stored.hourlyRate) > 0.000_001 else { return }
                    store.updateRateRule(id: rule.id, effectiveFrom: date, hourlyRate: value)
                }
            Text("/ hr").font(.system(size: 10)).foregroundStyle(.secondary)
            Button { store.deleteRateRule(id: rule.id) } label: {
                Image(systemName: "trash").foregroundStyle(canDelete ? .secondary : .tertiary)
            }
            .buttonStyle(.plain).disabled(!canDelete)
        }
        .padding(11)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
    }

    private func commit(date: Date) {
        let normalized = rateText.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value >= 0 else {
            rateText = String(format: "%.2f", rule.hourlyRate)
            return
        }
        store.updateRateRule(id: rule.id, effectiveFrom: date, hourlyRate: value)
        rateText = String(format: "%.2f", value)
    }
}
