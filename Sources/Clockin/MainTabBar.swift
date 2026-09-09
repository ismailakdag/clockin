import SwiftUI

/// Ana pencerenin gidilebilecek yerleri.
///
/// Onceden her ekran ayri bir boolean'di ve `if/else if` zinciriyle
/// birbirini disliyordu; geri donmek icin her ekranda ayri bir ok vardi.
/// Gecmis'ten Heatmap'e gecmek iki adim sururdu.
enum MainTab: String, CaseIterable, Identifiable {
    case dashboard, history, heatmap, progress, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "Timer"
        case .history:   return "History"
        case .heatmap:   return "Heatmap"
        case .progress:  return "Progress"
        case .settings:  return "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .dashboard: return "timer"
        case .history:   return "chart.bar.xaxis"
        case .heatmap:   return "square.grid.3x3.fill"
        case .progress:  return "trophy.fill"
        case .settings:  return "gearshape.fill"
        }
    }
}

struct MainTabBar: View {
    @AppStorage(UIScale.key) private var uiScaleObserver = 1.0
    @Binding var selection: MainTab
    let theme: ClockinPalette

    var body: some View {
        HStack(spacing: S(0)) {
            ForEach(MainTab.allCases) { tab in
                item(tab)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, S(6))
        .padding(.bottom, S(7))
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider().opacity(0.35) }
    }

    private func item(_ tab: MainTab) -> some View {
        let isOn = selection == tab
        return Button {
            selection = tab
        } label: {
            VStack(spacing: S(3)) {
                Image(systemName: tab.symbol)
                    .font(.system(size: S(15), weight: isOn ? .semibold : .regular))
                Text(tab.title)
                    .font(.system(size: S(8), weight: isOn ? .bold : .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(isOn ? theme.accent : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, S(3))
        }
        .buttonStyle(.hitTarget)
        .help(tab.title)
    }
}
