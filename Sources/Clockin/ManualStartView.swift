import SwiftUI

struct ManualStartView: View {
    @AppStorage(UIScale.key) private var uiScaleObserver = UIScale.defaultPercent
    @EnvironmentObject private var store: ClockStore
    @Environment(\.dismiss) private var dismiss
    @State private var hours = 0
    @State private var minutes = 0
    @State private var note = ""
    @AppStorage("Clockin.Theme") private var themeRaw = ClockinThemeChoice.carbon.rawValue

    private var elapsed: TimeInterval { TimeInterval(hours * 3600 + minutes * 60) }
    private var inferredStart: Date { Date().addingTimeInterval(-elapsed) }
    private var theme: ClockinPalette { ClockinThemeChoice.selected(themeRaw).palette }

    var body: some View {
        VStack(alignment: .leading, spacing: S(18)) {
            VStack(alignment: .leading, spacing: S(4)) {
                Text("Continue from elapsed time")
                    .font(.system(size: S(18), weight: .bold, design: .rounded))
                Text("The timer starts from this duration and keeps counting.")
                    .font(.system(size: S(11))).foregroundStyle(.secondary)
            }

            VStack(spacing: S(10)) {
                valueStepper(title: "Hours", value: $hours, range: 0...999)
                valueStepper(title: "Minutes", value: $minutes, range: 0...59)
            }

            VStack(alignment: .leading, spacing: S(6)) {
                Text("Note (optional)").font(ClockinFont.section).foregroundStyle(.secondary)
                ClockinTextField(placeholder: "What are you working on?", text: $note, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: S(12)) {
                VStack(alignment: .leading, spacing: S(3)) {
                    Text("Starts at \(inferredStart.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: S(11), weight: .semibold))
                    Text("Initial earnings: \((elapsed / 3600 * store.effectiveRate(at: .now, fallback: store.hourlyRate)).money(code: store.currencyCode))")
                        .font(.system(size: S(10))).foregroundStyle(.secondary)
                }
                HStack {
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(.clockin(.secondary)).foregroundStyle(.secondary)
                Button("Start") {
                    store.clockIn(elapsed: elapsed, note: note)
                    dismiss()
                }
                .buttonStyle(.clockin(.primary))
                .tint(theme.accent)
                .disabled(elapsed <= 0)
                }
            }
        }
        .padding(S(20))
        .frame(width: S(390), height: S(420))
        .background(theme.background)
        .fontDesign(theme.fontDesign)
        .preferredColorScheme(theme.colorScheme)
    }

    private func valueStepper(title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack(spacing: S(12)) {
            Text(title).font(ClockinFont.body).frame(width: S(58), alignment: .leading)
            HStack(spacing: S(6)) {
                Button { value.wrappedValue = max(range.lowerBound, value.wrappedValue - 1) } label: {
                    Image(systemName: "minus")
                }
                .buttonStyle(.clockinIcon(size: 28))
                .disabled(value.wrappedValue <= range.lowerBound)
                .help("Decrease \(title.lowercased())").accessibilityLabel("Decrease \(title.lowercased())")
                ClockinTextField(placeholder: "0", text: Binding(
                    get: { String(value.wrappedValue) },
                    set: { if let number = Int($0) { value.wrappedValue = min(range.upperBound, max(range.lowerBound, number)) } }
                ), alignment: .center)
                .accessibilityLabel(title)
                Button { value.wrappedValue = min(range.upperBound, value.wrappedValue + 1) } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.clockinIcon(size: 28))
                .disabled(value.wrappedValue >= range.upperBound)
                .help("Increase \(title.lowercased())").accessibilityLabel("Increase \(title.lowercased())")
            }

        }
        .padding(S(12)).frame(maxWidth: .infinity)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: S(11)))
    }
}
