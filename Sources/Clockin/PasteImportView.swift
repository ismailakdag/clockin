import AppKit
import SwiftUI

struct PasteImportView: View {
    @AppStorage(UIScale.key) private var uiScaleObserver = UIScale.defaultPercent
    @EnvironmentObject private var store: ClockStore
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var editorFocused: Bool
    @State private var showComparison = false
    @AppStorage("Clockin.Theme") private var themeRaw = ClockinThemeChoice.carbon.rawValue

    private var preview: [WorkSession] { store.previewPastedText(text) }
    private var theme: ClockinPalette { ClockinThemeChoice.selected(themeRaw).palette }
    private var previewDuration: TimeInterval { preview.reduce(0) { $0 + $1.duration } }
    private var approvedSummary: TimeInterval? { PastedTextImporter.approvedSummaryDuration(in: text) }

    var body: some View {
        VStack(alignment: .leading, spacing: S(14)) {
            HStack {
                VStack(alignment: .leading, spacing: S(3)) {
                    Text("Paste timecards").font(.system(size: S(18), weight: .bold, design: .rounded))
                    Text("One task or the entire page works.").font(.system(size: S(11))).foregroundStyle(.secondary)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").frame(width: S(28), height: S(28))
                }
                .buttonStyle(.clockinIcon()).help("Close").accessibilityLabel("Close")
                Button("Paste") {
                    text = NSPasteboard.general.string(forType: .string) ?? ""
                }.buttonStyle(.clockin(.tinted, size: .small))
            }

            TextEditor(text: $text)
                .focused($editorFocused)
                .accessibilityLabel("Timecard text")
                .font(.system(size: S(11), design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(S(8))
                .background(theme.control, in: RoundedRectangle(cornerRadius: S(9)))
                .overlay(RoundedRectangle(cornerRadius: S(9)).strokeBorder(editorFocused ? theme.accent : theme.controlStroke, lineWidth: editorFocused ? 1.5 : 1))
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("Paste your approved timecards here.")
                            .font(ClockinFont.caption).foregroundStyle(.secondary)
                            .padding(S(12)).allowsHitTesting(false)
                    }
                }

            VStack(alignment: .leading, spacing: S(12)) {
                VStack(alignment: .leading, spacing: S(2)) {
                    Text("\(preview.count) entries recognized")
                        .font(.system(size: S(12), weight: .semibold))
                    Text(preview.isEmpty && !text.isEmpty
                         ? "No complete date/start/end pattern found yet"
                         : DurationText.compact(previewDuration))
                        .font(.system(size: S(10))).foregroundStyle(.secondary)
                    if let approvedSummary {
                        Text("Page Approved: \(DurationText.compact(approvedSummary))")
                            .font(.system(size: S(10), weight: .semibold))
                        if abs(approvedSummary - previewDuration) > 60 {
                            Text("Copied rows are partial. Totals do not match.")
                                .font(.system(size: S(10), weight: .bold)).foregroundStyle(.orange)
                        } else {
                            Text("Copied rows match the page Approved total.")
                                .font(.system(size: S(10), weight: .bold)).foregroundStyle(theme.accent)
                        }
                    }
                }
                HStack {
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(.clockin(.secondary)).keyboardShortcut(.cancelAction)
                Button("Import") {
                    showComparison = true
                }
                .buttonStyle(.clockin(.primary))
                .tint(theme.accent)
                .disabled(preview.isEmpty)
                }
            }
        }
        .padding(S(18))
        .frame(width: S(390), height: S(480))
        .background(theme.background)
        .fontDesign(theme.fontDesign)
        .preferredColorScheme(theme.colorScheme)
        .sheet(isPresented: $showComparison) {
            ImportComparisonView(sessions: preview, sourceTitle: "Pasted timecards") {
                dismiss()
            }
            .environmentObject(store)
        }
    }
}
