import SwiftUI

struct SessionSummaryView: View {
    @AppStorage(UIScale.key) private var uiScaleObserver = UIScale.defaultPercent
    let session: WorkSession
    @EnvironmentObject private var store: ClockStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("Clockin.Theme") private var themeRaw = ClockinThemeChoice.carbon.rawValue
    private var theme: ClockinPalette { ClockinThemeChoice.selected(themeRaw).palette }
    private var xp: Int { Int(session.duration / 3600 * 100) }

    var body: some View {
        VStack(spacing: S(16)) {
            HStack { Text("Session complete").font(ClockinFont.section); Spacer(); Button { dismiss() } label: { Image(systemName: "xmark") }.buttonStyle(.clockinIcon()).help("Close").accessibilityLabel("Close") }
            VStack(spacing: S(5)) { Text("Session saved").font(.system(size: S(23), weight: .semibold, design: .rounded)); Text(session.note.isEmpty ? "Focus session" : session.note).font(.system(size: S(11))).foregroundStyle(.secondary) }
            HStack(spacing: S(0)) { metric("Time", DurationText.compact(session.duration)); Divider(); metric("Earned", store.earnings(for: session).money(code: store.currencyCode)); Divider(); metric("XP", "+\(xp)") }.fixedSize(horizontal: false, vertical: true).padding(S(14)).background(card)
            Button("Done") { dismiss() }.buttonStyle(.clockin(.primary, fullWidth: true)).tint(theme.accent).frame(maxWidth: .infinity)
        }.padding(S(20)).frame(width: S(350)).background(theme.background).preferredColorScheme(theme.colorScheme)
    }
    private func metric(_ title: String, _ value: String) -> some View { VStack(spacing: S(4)) { Text(title).font(.system(size: S(10), weight: .bold)).foregroundStyle(.secondary); Text(value).font(.system(size: S(14), weight: .bold, design: .rounded)) }.frame(maxWidth: .infinity) }
    private var card: some View {
        RoundedRectangle(cornerRadius: S(13), style: .continuous)
            .fill(theme.card)
            .overlay(RoundedRectangle(cornerRadius: S(13), style: .continuous).strokeBorder(theme.cardStroke))
    }
}
