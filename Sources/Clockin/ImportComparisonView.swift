import SwiftUI

struct ImportComparisonView: View {
    @AppStorage(UIScale.key) private var uiScaleObserver = 1.0
    @EnvironmentObject private var store: ClockStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("Clockin.Theme") private var themeRaw = ClockinThemeChoice.carbon.rawValue

    let sessions: [WorkSession]
    let sourceTitle: String
    let onImported: () -> Void

    /// Karsilastirma bir kez hesaplanir. Hesaplanan property olarak
    /// birakildiginda govdenin her erisiminde bastan kosuyordu.
    @State private var summary: ImportComparisonSummary?
    /// Aktarilacak kayitlar. Varsayilan olarak hepsi secili gelir.
    @State private var selected: Set<UUID> = []
    @State private var showSkipped = false

    private var theme: ClockinPalette { ClockinThemeChoice.selected(themeRaw).palette }

    /// Kullanicinin karar verebilecegi kayitlar: yeni olanlar ve mevcut bir
    /// sayac kaydini duzeltecek olanlar.
    private var actionable: [ImportComparisonItem] {
        guard let summary else { return [] }
        return summary.items.filter { $0.kind != .duplicate }
    }

    private var skipped: [ImportComparisonItem] {
        summary?.duplicateItems ?? []
    }

    private var selectedDuration: TimeInterval {
        actionable.filter { selected.contains($0.id) }.reduce(0) { $0 + $1.session.duration }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: S(13)) {
            header

            if let summary {
                HStack(spacing: S(8)) {
                    summaryCard("NEW", summary.newItems.count, color: theme.accent)
                    summaryCard("UPDATES", summary.matchedItems.count, color: .blue)
                    summaryCard("SKIP", summary.duplicateItems.count, color: .orange)
                }

                selectionBar

                ScrollView {
                    LazyVStack(spacing: S(6)) {
                        if actionable.isEmpty {
                            Text("Every entry in this file is already imported.")
                                .font(.system(size: S(10))).foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity).padding(.vertical, S(18))
                        }
                        // Aktarilacaklar once gelir; kullanicinin karar
                        // verecegi satirlar bunlar.
                        ForEach(actionable) { item in
                            row(item, selectable: true)
                        }

                        if !skipped.isEmpty {
                            skippedHeader
                            if showSkipped {
                                ForEach(skipped.prefix(60)) { item in
                                    row(item, selectable: false)
                                }
                                if skipped.count > 60 {
                                    Text("Showing first 60 of \(skipped.count) skipped")
                                        .font(.system(size: S(9))).foregroundStyle(.tertiary)
                                        .padding(.vertical, S(5))
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: S(300))
            } else {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, S(40))
            }

            footer
        }
        .padding(S(18))
        .frame(width: S(560), height: S(560))
        .background(theme.background)
        .fontDesign(theme.fontDesign)
        .preferredColorScheme(theme.colorScheme)
        .task {
            let computed = store.compareImportedSessions(sessions)
            summary = computed
            selected = Set(computed.items.filter { $0.kind != .duplicate }.map(\.id))
        }
    }

    private var header: some View {
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
    }

    private var selectionBar: some View {
        HStack {
            Text("SELECTED")
                .font(.system(size: S(9), weight: .bold)).foregroundStyle(.secondary).tracking(S(1))
            Spacer()
            Text("\(selected.count) of \(actionable.count) • \(DurationText.compact(selectedDuration))")
                .font(.system(size: S(10), weight: .semibold, design: .monospaced))
            if !actionable.isEmpty {
                Button(selected.count == actionable.count ? "None" : "All") {
                    selected = selected.count == actionable.count
                        ? []
                        : Set(actionable.map(\.id))
                }
                .buttonStyle(.plain).foregroundStyle(theme.accent)
                .font(.system(size: S(10), weight: .bold))
                .padding(.leading, S(8))
            }
        }
        .padding(S(10)).background(card)
    }

    private var skippedHeader: some View {
        Button { showSkipped.toggle() } label: {
            HStack(spacing: S(6)) {
                Image(systemName: showSkipped ? "chevron.down" : "chevron.right")
                    .font(.system(size: S(9), weight: .bold))
                Text("\(skipped.count) already imported")
                    .font(.system(size: S(9), weight: .bold, design: .monospaced))
                Spacer()
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, S(9)).padding(.vertical, S(7))
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        HStack {
            Button("Cancel") { dismiss() }.buttonStyle(.bordered)
            Spacer()
            Button("Import \(selected.count) \(selected.count == 1 ? "entry" : "entries")") {
                let chosen = actionable.filter { selected.contains($0.id) }.map(\.session)
                store.importSessions(chosen)
                onImported()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.accent)
            .foregroundStyle(.black)
            .disabled(selected.isEmpty)
        }
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

    private func row(_ item: ImportComparisonItem, selectable: Bool) -> some View {
        let isOn = selected.contains(item.id)
        return HStack(spacing: S(8)) {
            if selectable {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .font(.system(size: S(12)))
                    .foregroundStyle(isOn ? theme.accent : .secondary)
            } else {
                Image(systemName: "minus")
                    .font(.system(size: S(10)))
                    .foregroundStyle(.tertiary)
            }
            Text(item.kind.title)
                .font(.system(size: S(8), weight: .black, design: .monospaced))
                .foregroundStyle(item.kind == .new ? theme.accent : (item.kind == .matched ? .blue : .orange))
                .frame(width: S(54), alignment: .leading)
            Text(item.session.start.formatted(.dateTime.month(.abbreviated).day().year()))
                .font(.system(size: S(9), weight: .semibold, design: .monospaced))
                .frame(width: S(112), alignment: .leading)
            Text("\(item.session.start.formatted(.dateTime.hour().minute()))–\(item.session.end.formatted(.dateTime.hour().minute()))")
                .font(.system(size: S(9), design: .monospaced))
            Spacer()
            VStack(alignment: .trailing, spacing: S(2)) {
                Text(DurationText.compact(item.session.duration))
                    .font(.system(size: S(9), weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                // Bir kaydi guncelliyorsa eski deger de gosterilir.
                if let old = item.localMatch {
                    Text("was \(DurationText.compact(old.duration))")
                        .font(.system(size: S(7), design: .monospaced))
                        .foregroundStyle(.blue.opacity(0.8))
                }
            }
        }
        .opacity(selectable ? (isOn ? 1 : 0.45) : 0.5)
        .padding(.horizontal, S(9)).padding(.vertical, S(7))
        .background(theme.surface, in: RoundedRectangle(cornerRadius: S(7)))
        .contentShape(Rectangle())
        .onTapGesture {
            guard selectable else { return }
            if isOn { selected.remove(item.id) } else { selected.insert(item.id) }
        }
    }

    private var card: some View {
        RoundedRectangle(cornerRadius: S(10))
            .fill(theme.surface)
            .overlay(RoundedRectangle(cornerRadius: S(10)).stroke(theme.surfaceStroke))
    }
}
