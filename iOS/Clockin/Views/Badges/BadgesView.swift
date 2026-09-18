import SwiftUI

/// Seviye, seriler ve rozetler.
///
/// Once Insights'in icindeydi. Insights hedefler, isi haritasi, ritim ve
/// raporlarla zaten uzun bir sayfaydi; kirk alti rozet de eklenince
/// kaydirmak zorlasti. Alttaki Ayarlar sekmesi Bugun ekranina tasininca bos
/// kalan yere ilerleme kendi sekmesiyle geldi.
@MainActor
struct BadgesView: View {
    @EnvironmentObject private var store: ClockStore
    @ObservedObject private var celebrations = CelebrationCenter.shared
    @Environment(\.palette) private var palette

    @State private var showCompanion = false

    var body: some View {
        NavigationStack {
            Group {
                if let stats = celebrations.snapshot {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            levelCard(stats)
                            InsightsBadgesView(badges: stats.badges)
                            companionSection(totalHours: stats.totalDuration / 3600)
                        }
                        .padding(16)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
            }
            .background(palette.background)
            .navigationTitle("Badges")
        }
        .sheet(isPresented: $showCompanion) { CompanionView() }
        .celebrationBlocked(by: showCompanion)
        .tint(palette.accent)
        .fontDesign(palette.fontDesign)
    }

    private func companionSection(totalHours: Double) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle("COMPANION")
            Button { showCompanion = true } label: {
                Label("Outfits, coins and home", systemImage: "tshirt.fill")
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }

        }
        .padding(16).card(palette)
    }

    private func levelCard(_ stats: InsightsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Kupa bu uygulamada bir sey anlatmiyordu (Bugun ekranindan da
            // kaldirilmisti); sekmenin ikonu olan rozet kullaniliyor.
            Label("Level \(stats.level)", systemImage: "rosette")
                .contentTransition(.numericText())
                .font(.title2.bold())
                .foregroundStyle(palette.accent)
            Text("\(stats.xp.formatted()) XP")
                .font(.headline).monospacedDigit()
                .contentTransition(.numericText())
            SwiftUI.ProgressView(value: Double(stats.xp % 500) / 500)
                .accessibilityLabel("Progress to next level")
            Text("\(500 - stats.xp % 500) XP to level \(stats.level + 1)")
                .font(.subheadline).foregroundStyle(.secondary)
            Divider()
            metric("Current streak", value: "\(stats.currentStreak) days")
            metric("Longest streak", value: "\(stats.longestStreak) days")
            DisclosureGroup("How XP works") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("100 XP per hour: \(stats.baseXP.formatted()) XP")
                    Text("Streaks: +\(stats.streakXP.formatted()) XP")
                    Text("Streak bonuses add up: 3 days +100, 7 +250, 14 +500, 30 +1,000 and 60 +2,000 XP.")
                    Text("Goals do not add XP. They are yours to set, so a level built on them would not mean the same thing for everyone.")
                }
                .font(.footnote).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
            }
            .font(.subheadline)
            if let running = store.running {
                Label(running.isPaused ? "Includes paused session" : "Includes running session • updates every minute",
                      systemImage: running.isPaused ? "pause.circle" : "clock")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(16).card(palette)
    }

    private func metric(_ title: String, value: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).foregroundStyle(.secondary)
                Spacer(minLength: 12)
                Text(value).fontWeight(.semibold).monospacedDigit()
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).foregroundStyle(.secondary)
                Text(value).fontWeight(.semibold).monospacedDigit()
            }
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }
}
