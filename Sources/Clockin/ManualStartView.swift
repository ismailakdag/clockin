import SwiftUI

struct ManualStartView: View {
    @AppStorage(UIScale.key) private var uiScaleObserver = 1.0
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

            HStack(spacing: S(12)) {
                valueStepper(title: "HOURS", value: $hours, range: 0...999)
                valueStepper(title: "MINUTES", value: $minutes, range: 0...59)
            }

            VStack(alignment: .leading, spacing: S(6)) {
                Text("NOTE (OPTIONAL)").font(.system(size: S(9), weight: .bold)).foregroundStyle(.secondary).tracking(S(1))
                TextField("What are you working on?", text: $note)
                    .textFieldStyle(.plain).padding(S(10))
                    .background(theme.surface, in: RoundedRectangle(cornerRadius: S(9)))
            }

            HStack {
                VStack(alignment: .leading, spacing: S(3)) {
                    Text("Starts at \(inferredStart.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: S(11), weight: .semibold))
                    Text("Initial earnings: \((elapsed / 3600 * store.hourlyRate).money(code: store.currencyCode))")
                        .font(.system(size: S(10))).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(.plain).foregroundStyle(.secondary)
                Button("Start") {
                    store.clockIn(elapsed: elapsed, note: note)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accent)
                .foregroundStyle(.black)
                .disabled(elapsed <= 0)
            }
        }
        .padding(S(20))
        .frame(width: S(430), height: S(330))
        .background(theme.background)
        .fontDesign(theme.fontDesign)
        .preferredColorScheme(theme.colorScheme)
    }

    private func valueStepper(title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        VStack(alignment: .leading, spacing: S(6)) {
            Text(title).font(.system(size: S(9), weight: .bold)).foregroundStyle(.secondary).tracking(S(1))
            HStack(spacing: S(8)) {
                TextField("0", value: value, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: S(23), weight: .semibold, design: .monospaced))
                    .multilineTextAlignment(.leading)
                    .frame(width: S(78))
                    .onChange(of: value.wrappedValue) { _, newValue in
                        let clamped = min(range.upperBound, max(range.lowerBound, newValue))
                        if clamped != newValue { value.wrappedValue = clamped }
                    }
                Stepper("", value: value, in: range).labelsHidden().controlSize(.small)
            }
        }
        .padding(S(12)).frame(maxWidth: .infinity)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: S(11)))
    }
}
