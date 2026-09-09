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
    static let key = "Clockin.UIScalePercent"
    private static let legacyKey = "Clockin.UIScale"
    static let base = CGSize(width: 390, height: 650)

    /// Yuzde olarak saklanir. Oran bir Double oldugunda ayardaki Picker
    /// secimi ondalik esitlige dayaniyordu; deger bir kez 32 bitlik float
    /// olarak yazildiginda (1.2999999523...) hicbir secenekle eslesmiyor ve
    /// Picker sessizce bos goruunuyordu. Tam sayi bu sinifi ortadan kaldirir.
    static let options = [100, 115, 130, 150]
    static let defaultPercent = 100

    static var percent: Int {
        let stored = UserDefaults.standard.integer(forKey: key)
        return options.contains(stored) ? stored : defaultPercent
    }

    static var current: Double { Double(percent) / 100 }

    static func label(for percent: Int) -> String { "\(percent)%" }

    /// Double olarak saklanan eski degeri en yakin secenege tasir.
    static func migrateLegacyValueIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: key) == nil else { return }
        guard let legacy = defaults.object(forKey: legacyKey) as? Double, legacy > 0 else { return }
        let nearest = options.min {
            abs(Double($0) / 100 - legacy) < abs(Double($1) / 100 - legacy)
        } ?? defaultPercent
        defaults.set(nearest, forKey: key)
        defaults.removeObject(forKey: legacyKey)
    }

    /// Verilen oranda pencerenin en kucuk icerik boyutu.
    static func minimumContentSize(for scale: Double) -> CGSize {
        let s = min(max(scale, 1), 2)
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
