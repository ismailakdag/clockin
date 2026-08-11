import SwiftUI

struct ImportComparisonView: View {
    @AppStorage(UIScale.key) private var uiScaleObserver = 1.0
    @EnvironmentObject private var store: ClockStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("Clockin.Theme") private var themeRaw = ClockinThemeChoice.carbon.rawValue

    let sessions: [WorkSession]
    let sourceTitle: String
    let onImported: () -> Void

    private var theme: ClockinPalette { ClockinThemeChoice.selected(themeRaw).palette }
    private var summary: ImportComparisonSummary { store.compareImportedSessions(sessions) }

    var body: some View {
        VStack(alignment: .leading, spacing: S(13)) {
            HStack {
                VStack(alignment: .leading, spacing: S(3)) {
                    Text("Compare before import")
                        .font(.system(size: S(18), weight: .bold, design: .rounded))
                    Text("\(sourceTitle) • The newest external record is authoritative; updates replace older local values.")
                        .font(.system(size: S(10))).foregroundStyle(.secondary)
                }
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark").frame(width: S(28), height: S(28)) }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
            }

            HStack(spacing: S(8)) {
                summaryCard("NEW", summary.newItems.count, color: theme.accent)
                summaryCard("UPDATES", summary.matchedItems.count, color: .blue)
                summaryCard("SKIP", summary.duplicateItems.count, color: .orange)
            }

            HStack {
                Text("TOTAL IMPORT")
                    .font(.system(size: S(9), weight: .bold)).foregroundStyle(.secondary).tracking(S(1))
                Spacer()
                Text("\(sessions.count) entries • \(DurationText.compact(summary.totalDuration))")
                    .font(.system(size: S(10), weight: .semibold, design: .monospaced))
            }
            .padding(S(10)).background(card)

            ScrollView {
                LazyVStack(spacing: S(6)) {
                    ForEach(summary.items.prefix(40)) { item in
                        row(item)
                    }
                    if summary.items.count > 40 {
                        Text("Showing first 40 of \(summary.items.count) entries")
                            .font(.system(size: S(9))).foregroundStyle(.tertiary).padding(.vertical, S(5))
                    }
                }
            }
            .frame(maxHeight: S(300))

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
        .padding(S(18))
        .frame(width: S(560), height: S(560))
        .background(theme.background)
        .fontDesign(theme.fontDesign)
        .preferredColorScheme(theme.colorScheme)
    }

    private func summaryCard(_ label: String, _ value: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: S(4)) {
            Text(label).font(.system(size: S(8), weight: .bold, design: .monospaced)).foregroundStyle(.secondary)
            Text("\(value)").font(.system(size: S(19), weight: .black, design: .monospaced)).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(S(10))
        .background(card)
    }

    private func row(_ item: ImportComparisonItem) -> some View {
        HStack(spacing: S(8)) {
            Text(item.kind.title)
                .font(.system(size: S(8), weight: .black, design: .monospaced))
                .foregroundStyle(item.kind == .new ? theme.accent : (item.kind == .matched ? .blue : .orange))
                .frame(width: S(54), alignment: .leading)
            Text(item.session.start.formatted(.dateTime.month(.abbreviated).day().year()))
                .font(.system(size: S(9), weight: .semibold, design: .monospaced))
                .frame(width: S(112), alignment: .leading)
            Text("\(item.session.start.formatted(.dateTime.hour().minute()))–\(item.session.end.formatted(.dateTime.hour().minute()))")
                .font(.system(size: S(9), design: .monospaced))
            VStack(alignment: .trailing, spacing: S(2)) {
                Text(DurationText.compact(item.session.duration))
                    .font(.system(size: S(9), weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                if let old = item.localMatch {
                    Text("was \(DurationText.compact(old.duration))")
                        .font(.system(size: S(7), design: .monospaced))
                        .foregroundStyle(.blue.opacity(0.8))
                }
            }
        }
        .padding(.horizontal, S(9)).padding(.vertical, S(7))
        .background(theme.surface, in: RoundedRectangle(cornerRadius: S(7)))
    }

    private var card: some View {
        RoundedRectangle(cornerRadius: S(10))
            .fill(theme.surface)
            .overlay(RoundedRectangle(cornerRadius: S(10)).stroke(theme.surfaceStroke))
    }
}
