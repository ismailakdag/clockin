import SwiftUI

struct SessionSummaryView: View {
    let session: WorkSession
    @EnvironmentObject private var store: ClockStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("Clockin.Theme") private var themeRaw = ClockinThemeChoice.carbon.rawValue
    private var theme: ClockinPalette { ClockinThemeChoice.selected(themeRaw).palette }
    private var xp: Int { Int(session.duration / 3600 * 100) }

    var body: some View {
        VStack(spacing: 16) {
            HStack { Text("SESSION COMPLETE").font(.system(size: 12, weight: .black)).tracking(1.2); Spacer(); Button { dismiss() } label: { Image(systemName: "xmark") }.buttonStyle(.plain) }
            VStack(spacing: 5) { Text("Nice work!").font(.system(size: 28, weight: .black, design: .rounded)); Text(session.note.isEmpty ? "Focus session" : session.note).font(.system(size: 11)).foregroundStyle(.secondary) }
            HStack(spacing: 0) { metric("TIME", DurationText.compact(session.duration)); Divider(); metric("EARNED", store.earnings(for: session).money(code: store.currencyCode)); Divider(); metric("XP", "+\(xp)") }.padding(14).background(card)
            HStack { Image(systemName: "sparkles").foregroundStyle(theme.accent); Text("Every focused hour makes your companion stronger.").font(.system(size: 10, weight: .semibold)); Spacer() }.padding(11).background(card)
            Button("Done") { dismiss() }.buttonStyle(.borderedProminent).tint(theme.accent).frame(maxWidth: .infinity)
        }.padding(20).frame(width: 350).background(theme.background).preferredColorScheme(.dark)
    }
    private func metric(_ title: String, _ value: String) -> some View { VStack(spacing: 4) { Text(title).font(.system(size: 8, weight: .bold)).foregroundStyle(.secondary); Text(value).font(.system(size: 14, weight: .bold, design: .rounded)) }.frame(maxWidth: .infinity) }
    private var card: some ShapeStyle { .black.opacity(0.16) }
}
