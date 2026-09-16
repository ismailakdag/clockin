import SwiftUI

struct GuideView: View {
    @AppStorage(UIScale.key) private var uiScaleObserver = UIScale.defaultPercent
    @Environment(\.dismiss) private var dismiss
    @AppStorage("Clockin.Theme") private var themeRaw = ClockinThemeChoice.carbon.rawValue

    private var theme: ClockinPalette { ClockinThemeChoice.selected(themeRaw).palette }

    var body: some View {
        VStack(spacing: S(0)) {
            HStack {
                VStack(alignment: .leading, spacing: S(3)) {
                    Text("How to use Clockin")
                        .font(.system(size: S(14), weight: .black, design: theme.fontDesign))
                    Text("A quick guide for tracking, importing and reviewing your time")
                        .font(.system(size: S(10))).foregroundStyle(.secondary)
                }
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark").frame(width: S(28), height: S(28)) }
                    .buttonStyle(.clockinIcon()).help("Close").accessibilityLabel("Close")
            }
            .padding(.horizontal, S(16)).frame(height: S(58))
            .overlay(alignment: .bottom) { Divider().opacity(0.25) }

            ScrollView {
                VStack(alignment: .leading, spacing: S(12)) {
                    guideSection("1", "Start a session", "Press Clock in on the home screen. Pause keeps the session open without adding time; Resume continues it. Clock out saves the session and opens its summary. If you started late, use Manual elapsed time to continue from an existing duration.", "play.fill")
                    guideSection("2", "Bring in My Time history", "In your My Time / timecard page, select the full date range you need first (for example Dec 31, 2025 – Aug 31, 2026). Export the CSV, then in Clockin open Settings → Data → Import CSV. The preview marks New, Updates and Skip before anything is added.", "calendar.badge.clock")
                    guideSection("3", "Paste an approved page", "If CSV export is unavailable, copy the entire approved page or a task block. Open Settings → Data → Paste timecards, press Paste, review the recognized rows and the Approved total, then continue to Compare before import. Exact duplicates are skipped automatically.", "doc.on.clipboard")
                    guideSection("4", "Keep historical rates correct", "Open Settings → Pay → Rate schedule → Manage. Add a start date, optionally an end date, and the hourly rate for that period. Existing sessions use their historical rate; new sessions use the currently active period.", "calendar.badge.plus")
                    guideSection("5", "Read your progress", "Earnings History shows daily money, hours, USD/TRY and hover details. Work Heatmap shows rhythm by day, week, month or all time. Progress contains goals, streaks, records, badges and the shareable summary.", "chart.bar.xaxis")
                    guideSection("6", "Use the desktop tools", "Pin the widget to keep the timer visible. Money, Goal and All modes can be resized and remember their size. The menu bar and keyboard shortcuts keep Clockin usable while another app is focused.", "pin.fill")
                    guideSection("7", "Back up safely", "Clockin creates an automatic backup at most once a day and keeps the last 30. Settings → Data lets you export a portable JSON backup, restore a file, or restore the latest automatic backup. Restore only when you want to replace the current data.", "externaldrive.fill")
                    Text("Tip: import the oldest history first, check the comparison totals, then add newer exports. This makes rate periods and duplicate matching easier to audit.")
                        .font(.system(size: S(10), weight: .medium)).foregroundStyle(theme.accent)
                        .padding(S(12)).background(theme.surface, in: RoundedRectangle(cornerRadius: S(11)))
                }
                .padding(S(16))
            }
        }
        .frame(width: S(390), height: S(670))
        .scrollBounceBehavior(.basedOnSize)
        .background(theme.background)
        .fontDesign(theme.fontDesign)
        .clockinTextStyles()
        .preferredColorScheme(theme.colorScheme)
    }

    private func guideSection(_ number: String, _ title: String, _ detail: String, _ icon: String) -> some View {
        HStack(alignment: .top, spacing: S(11)) {
            ZStack {
                Circle().fill(theme.accent.opacity(0.15)).frame(width: S(31), height: S(31))
                Image(systemName: icon).font(.system(size: S(13), weight: .bold)).foregroundStyle(theme.accent)
            }
            VStack(alignment: .leading, spacing: S(4)) {
                HStack(spacing: S(6)) {
                    Text(number).font(.system(size: S(10), weight: .black, design: .monospaced)).foregroundStyle(theme.accent)
                    Text(title).font(.system(size: S(11), weight: .bold))
                }
                Text(detail).font(.system(size: S(10))).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(S(11))
        .background(theme.surface, in: RoundedRectangle(cornerRadius: S(11)))
    }
}
