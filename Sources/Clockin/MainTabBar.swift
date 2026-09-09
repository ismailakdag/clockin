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
    @AppStorage(UIScale.key) private var uiScaleObserver = UIScale.defaultPercent
    @Binding var selection: MainTab
    let theme: ClockinPalette

    /// Secim gostergesinin sekmeler arasinda kaymasi icin ortak alan.
    @Namespace private var indicator

    var body: some View {
        HStack(spacing: S(0)) {
            ForEach(MainTab.allCases) { tab in
                item(tab)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, S(6))
        .padding(.top, S(6))
        .padding(.bottom, S(7))
        // Malzemenin kendisi zaten en seffaf olani; opaklgi biraz daha
        // dusurmek arkadaki icerigi daha fazla gecirir.
        .background {
            Rectangle().fill(.ultraThinMaterial).opacity(0.78)
        }
        .overlay(alignment: .top) { Divider().opacity(0.22) }
    }

    private func item(_ tab: MainTab) -> some View {
        let isOn = selection == tab
        return Button {
            withAnimation(.snappy(duration: 0.22)) { selection = tab }
        } label: {
            VStack(spacing: S(3)) {
                Image(systemName: tab.symbol)
                    .font(.system(size: S(15), weight: isOn ? .semibold : .regular))
                    .scaleEffect(isOn ? 1.06 : 1)
                Text(tab.title)
                    .font(.system(size: S(8), weight: isOn ? .bold : .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(isOn ? theme.accent : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, S(5))
            .background {
                if isOn {
                    RoundedRectangle(cornerRadius: S(10), style: .continuous)
                        .fill(theme.accent.opacity(0.16))
                        .overlay {
                            RoundedRectangle(cornerRadius: S(10), style: .continuous)
                                .stroke(theme.accent.opacity(0.30), lineWidth: 1)
                        }
                        // Ayni kimlik sayesinde gosterge silinip yeniden
                        // cizilmek yerine yeni sekmeye kayar.
                        .matchedGeometryEffect(id: "selection", in: indicator)
                }
            }
        }
        .buttonStyle(.hitTarget)
        .help(tab.title)
    }
}
