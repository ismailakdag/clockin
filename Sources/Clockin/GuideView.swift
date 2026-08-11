import SwiftUI

struct GuideView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("Clockin.Theme") private var themeRaw = ClockinThemeChoice.carbon.rawValue

    private var theme: ClockinPalette { ClockinThemeChoice.selected(themeRaw).palette }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("HOW TO USE CLOCKIN")
                        .font(.system(size: 14, weight: .black, design: theme.fontDesign)).tracking(1.2)
                    Text("A quick guide for tracking, importing and reviewing your time")
                        .font(.system(size: 9)).foregroundStyle(.secondary)
                }
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark").frame(width: 28, height: 28) }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16).frame(height: 58)
            .overlay(alignment: .bottom) { Divider().opacity(0.25) }

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    guideSection("1", "Start a session", "Press Clock in on the home screen. Pause keeps the session open without adding time; Resume continues it. Clock out saves the session and opens its summary. If you started late, use Manual elapsed time to continue from an existing duration.", "play.fill")
                    guideSection("2", "Bring in My Time history", "In your My Time / timecard page, select the full date range you need first (for example Dec 31, 2025 – Aug 31, 2026). Export the CSV, then in Clockin open Settings → Data → Import timesheet CSV. The preview marks NEW, MATCHED and SKIP before anything is added.", "calendar.badge.clock")
                    guideSection("3", "Paste an approved page", "If CSV export is unavailable, copy the entire approved page or a task block. Open Paste approved timecards, press Paste, review the recognized rows and the Approved total, then continue to Compare before import. Exact duplicates are skipped automatically.", "doc.on.clipboard")
                    guideSection("4", "Keep historical rates correct", "Open Settings → Pay & Currency → Manage under Rate Schedule. Add a start date, optionally an end date, and the hourly rate for that period. Existing sessions use their historical rate; new sessions use the currently active period.", "calendar.badge.plus")
                    guideSection("5", "Read your progress", "Earnings History shows daily money, hours, USD/TRY and hover details. Work Heatmap shows rhythm by day, week, month or all time. Progress contains goals, streaks, records, badges and the shareable rewind.", "chart.bar.xaxis")
                    guideSection("6", "Use the desktop tools", "Pin the widget to keep the timer visible. Money, Goal and All modes can be resized and remember their size. The menu bar and keyboard shortcuts keep Clockin usable while another app is focused.", "pin.fill")
                    guideSection("7", "Back up safely", "Clockin creates automatic backups before saves. Settings → Data lets you export a portable JSON backup, restore a file, or restore the latest automatic backup. Restore only when you want to replace the current data.", "externaldrive.fill")
                    Text("Tip: import the oldest history first, check the comparison totals, then add newer exports. This makes rate periods and duplicate matching easier to audit.")
                        .font(.system(size: 10, weight: .medium)).foregroundStyle(theme.accent)
                        .padding(12).background(theme.surface, in: RoundedRectangle(cornerRadius: 11))
                }
                .padding(16)
            }
        }
        .frame(width: 590, height: 670)
        .background(theme.background)
        .fontDesign(theme.fontDesign)
        .preferredColorScheme(theme.colorScheme)
    }

    private func guideSection(_ number: String, _ title: String, _ detail: String, _ icon: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            ZStack {
                Circle().fill(theme.accent.opacity(0.15)).frame(width: 31, height: 31)
                Image(systemName: icon).font(.system(size: 13, weight: .bold)).foregroundStyle(theme.accent)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(number).font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(theme.accent)
                    Text(title).font(.system(size: 11, weight: .bold))
                }
                Text(detail).font(.system(size: 9.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(11)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 11))
    }
}
