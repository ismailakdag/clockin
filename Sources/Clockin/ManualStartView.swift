import SwiftUI

struct ManualStartView: View {
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
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Continue from elapsed time")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text("The timer starts from this duration and keeps counting.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                valueStepper(title: "HOURS", value: $hours, range: 0...999)
                valueStepper(title: "MINUTES", value: $minutes, range: 0...59)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("NOTE (OPTIONAL)").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary).tracking(1)
                TextField("What are you working on?", text: $note)
                    .textFieldStyle(.plain).padding(10)
                    .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 9))
            }

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Starts at \(inferredStart.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Initial earnings: \((elapsed / 3600 * store.hourlyRate).money(code: store.currencyCode))")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
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
        .padding(20)
        .frame(width: 430, height: 330)
        .background(theme.background)
        .fontDesign(theme.fontDesign)
        .preferredColorScheme(.dark)
    }

    private func valueStepper(title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary).tracking(1)
            Stepper(value: value, in: range) {
                Text("\(value.wrappedValue)")
                    .font(.system(size: 25, weight: .semibold, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12).frame(maxWidth: .infinity)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 11))
    }
}
