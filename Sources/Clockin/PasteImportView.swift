import AppKit
import SwiftUI

struct PasteImportView: View {
    @EnvironmentObject private var store: ClockStore
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @AppStorage("Clockin.Theme") private var themeRaw = ClockinThemeChoice.carbon.rawValue

    private var preview: [WorkSession] { store.previewPastedText(text) }
    private var theme: ClockinPalette { ClockinThemeChoice.selected(themeRaw).palette }
    private var previewDuration: TimeInterval { preview.reduce(0) { $0 + $1.duration } }
    private var approvedSummary: TimeInterval? { PastedTextImporter.approvedSummaryDuration(in: text) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Paste timecards").font(.system(size: 18, weight: .bold, design: .rounded))
                    Text("One task or the entire page works.").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").frame(width: 28, height: 28)
                }
                .buttonStyle(.plain).foregroundStyle(.secondary).help("Close")
                Button("Paste") {
                    text = NSPasteboard.general.string(forType: .string) ?? ""
                }
            }

            TextEditor(text: $text)
                .font(.system(size: 11, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.08)))

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(preview.count) entries recognized")
                        .font(.system(size: 12, weight: .semibold))
                    Text(preview.isEmpty && !text.isEmpty
                         ? "No complete date/start/end pattern found yet"
                         : DurationText.compact(previewDuration))
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                    if let approvedSummary {
                        Text("Page Approved: \(DurationText.compact(approvedSummary))")
                            .font(.system(size: 10, weight: .semibold))
                        if abs(approvedSummary - previewDuration) > 60 {
                            Text("Copied rows are partial — totals do not match.")
                                .font(.system(size: 9, weight: .bold)).foregroundStyle(.orange)
                        } else {
                            Text("Copied rows match the page Approved total.")
                                .font(.system(size: 9, weight: .bold)).foregroundStyle(theme.accent)
                        }
                    }
                }
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(.bordered).keyboardShortcut(.cancelAction)
                Button("Import") {
                    store.importPastedText(text)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accent)
                .foregroundStyle(.black)
                .disabled(preview.isEmpty)
            }
        }
        .padding(18)
        .frame(width: 520, height: 430)
        .background(theme.background)
        .fontDesign(theme.fontDesign)
        .preferredColorScheme(.dark)
    }
}
