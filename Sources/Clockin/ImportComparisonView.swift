import SwiftUI

struct ImportComparisonView: View {
    @EnvironmentObject private var store: ClockStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("Clockin.Theme") private var themeRaw = ClockinThemeChoice.carbon.rawValue

    let sessions: [WorkSession]
    let sourceTitle: String
    let onImported: () -> Void

    private var theme: ClockinPalette { ClockinThemeChoice.selected(themeRaw).palette }
    private var summary: ImportComparisonSummary { store.compareImportedSessions(sessions) }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Compare before import")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text("\(sourceTitle) • The newest external record is authoritative; updates replace older local values.")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark").frame(width: 28, height: 28) }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                summaryCard("NEW", summary.newItems.count, color: theme.accent)
                summaryCard("UPDATES", summary.matchedItems.count, color: .blue)
                summaryCard("SKIP", summary.duplicateItems.count, color: .orange)
            }

            HStack {
                Text("TOTAL IMPORT")
                    .font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary).tracking(1)
                Spacer()
                Text("\(sessions.count) entries • \(DurationText.compact(summary.totalDuration))")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
            }
            .padding(10).background(card)

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(summary.items.prefix(40)) { item in
                        row(item)
                    }
                    if summary.items.count > 40 {
                        Text("Showing first 40 of \(summary.items.count) entries")
                            .font(.system(size: 9)).foregroundStyle(.tertiary).padding(.vertical, 5)
                    }
                }
            }
            .frame(maxHeight: 300)

            HStack {
                Button("Cancel") { dismiss() }.buttonStyle(.bordered)
                Spacer()
                Button("Apply \(summary.newItems.count) new + \(summary.matchedItems.count) updates") {
                    store.importSessions(sessions)
                    onImported()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accent)
                .foregroundStyle(.black)
                .disabled(summary.newItems.isEmpty && summary.matchedItems.isEmpty)
            }
        }
        .padding(18)
        .frame(width: 560, height: 560)
        .background(theme.background)
        .fontDesign(theme.fontDesign)
        .preferredColorScheme(theme.colorScheme)
    }

    private func summaryCard(_ label: String, _ value: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(.secondary)
            Text("\(value)").font(.system(size: 19, weight: .black, design: .monospaced)).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(card)
    }

    private func row(_ item: ImportComparisonItem) -> some View {
        HStack(spacing: 8) {
            Text(item.kind.title)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(item.kind == .new ? theme.accent : (item.kind == .matched ? .blue : .orange))
                .frame(width: 54, alignment: .leading)
            Text(item.session.start.formatted(.dateTime.month(.abbreviated).day().year()))
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .frame(width: 112, alignment: .leading)
            Text("\(item.session.start.formatted(.dateTime.hour().minute()))–\(item.session.end.formatted(.dateTime.hour().minute()))")
                .font(.system(size: 9, design: .monospaced))
            VStack(alignment: .trailing, spacing: 2) {
                Text(DurationText.compact(item.session.duration))
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                if let old = item.localMatch {
                    Text("was \(DurationText.compact(old.duration))")
                        .font(.system(size: 7, design: .monospaced))
                        .foregroundStyle(.blue.opacity(0.8))
                }
            }
        }
        .padding(.horizontal, 9).padding(.vertical, 7)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 7))
    }

    private var card: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(theme.surface)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.surfaceStroke))
    }
}
