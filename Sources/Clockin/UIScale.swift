import SwiftUI

/// Arayuz yakinlastirma orani.
///
/// Ekranlar sabit bir 390x650 tuvale gore tasarlanmis ve punto degerleri
/// koda gomulu (yaklasik 300 yerde). Bunlari tek tek buyutmek yerlesimi
/// bozardi; bunun yerine tuval oransal olarak olceklenir.
///
/// Icerik once "mantiksal" boyutta yerlestirilir (pencere boyutu / oran),
/// sonra oranla carpilir. Boylece yazi ve ikonlar buyur, pencereyi
/// buyutmekle kazanilan fazla alan da listelere yarar.
enum UIScale {
    static let key = "Clockin.UIScale"
    static let base = CGSize(width: 390, height: 650)

    static let options: [(label: String, value: Double)] = [
        ("100%", 1.00),
        ("115%", 1.15),
        ("130%", 1.30),
        ("150%", 1.50),
    ]

    static var current: Double {
        let stored = UserDefaults.standard.double(forKey: key)
        return clamp(stored)
    }

    /// Kayitli deger yoksa (0) veya beklenmedik bir deger geldiyse guvenli
    /// bir orana indirger.
    static func clamp(_ value: Double) -> Double {
        guard value > 0, value.isFinite else { return 1 }
        return min(max(value, 1), 2)
    }

    /// Verilen oranda pencerenin en kucuk icerik boyutu.
    static func minimumContentSize(for scale: Double) -> CGSize {
        let s = clamp(scale)
        return CGSize(width: (base.width * s).rounded(), height: (base.height * s).rounded())
    }
}

/// Icerigi mantiksal boyutta yerlestirip oranla olcekler.
///
/// `GeometryReader` olmadan `scaleEffect` yalnizca gorsel bir donusum olur:
/// yerlesim hala eski boyutu varsayar ve icerik tasar. Once mantiksal
/// boyut verilip sonra olceklenmesi, iki sorunu birden cozer.
struct ScaledCanvas<Content: View>: View {
    /// Ayari dogrudan dinler; kullanici orani degistirdiginde pencereyi
    /// yeniden kurmadan aninda uygulanir.
    @AppStorage(UIScale.key) private var storedScale = 1.0
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { geo in
            let s = UIScale.clamp(storedScale)
            content
                .frame(width: max(geo.size.width / s, 1), height: max(geo.size.height / s, 1))
                .scaleEffect(s, anchor: .topLeading)
        }
    }
}
