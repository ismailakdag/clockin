import SwiftUI

/// Arayuz boyut orani.
///
/// Ekranlar sabit bir 390x650 tuvale gore tasarlanmis ve butun olculer koda
/// gomulu. Tuvali `scaleEffect` ile buyutmek kolay olurdu ama icerik once
/// kendi boyutunda cizilip sonra yeniden orneklendigi icin yazilar ve
/// bilerek keskin birakilan pixel-art gorseller bulaniklasiyor.
///
/// Bunun yerine olculerin kendisi buyutulur: punto, bosluk ve boyutlar
/// `S(_:)` uzerinden gecer, dolayisiyla yazi hedef boyutunda cizilir ve
/// her oranda keskin kalir.
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
        clamp(UserDefaults.standard.double(forKey: key))
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

/// Tasarim olcusunu gecerli orana tasir.
///
/// Global tutulmasinin sebebi, olculerin gorunum govdelerinin her yerinde
/// olmasi: ortam degeri olarak tasimak her cagri noktasini degistirmeyi
/// gerektirirdi. Gorunumler orani ayrica `@AppStorage(UIScale.key)` ile
/// dinler; oran degisince yeniden cizilirler.
func S(_ value: CGFloat) -> CGFloat {
    value * UIScale.current
}
