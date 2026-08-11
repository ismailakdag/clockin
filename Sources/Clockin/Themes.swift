import SwiftUI

enum ClockinThemeChoice: String, CaseIterable, Identifiable {
    case carbon = "Carbon"
    case neonOrange = "Neon Orange"
    case electricBlue = "Electric Blue"
    case synthwave = "Synthwave"
    case dataDense = "Data Dense"

    var id: String { rawValue }

    var palette: ClockinPalette {
        switch self {
        case .carbon:
            ClockinPalette(background: Color(red: 0.055, green: 0.065, blue: 0.08), accent: Color(red: 0.35, green: 0.95, blue: 0.58), secondary: .cyan, fontDesign: .rounded)
        case .neonOrange:
            ClockinPalette(background: Color(red: 0.075, green: 0.045, blue: 0.025), accent: Color(red: 1.0, green: 0.43, blue: 0.08), secondary: Color(red: 1.0, green: 0.78, blue: 0.16), fontDesign: .monospaced)
        case .electricBlue:
            ClockinPalette(background: Color(red: 0.025, green: 0.055, blue: 0.105), accent: Color(red: 0.15, green: 0.68, blue: 1.0), secondary: Color(red: 0.26, green: 0.94, blue: 1.0), fontDesign: .default)
        case .synthwave:
            ClockinPalette(background: Color(red: 0.075, green: 0.025, blue: 0.105), accent: Color(red: 1.0, green: 0.24, blue: 0.72), secondary: Color(red: 0.2, green: 0.95, blue: 1.0), fontDesign: .serif)
        case .dataDense:
            ClockinPalette(background: Color(red: 0.015, green: 0.02, blue: 0.018), accent: Color(red: 0.72, green: 1.0, blue: 0.18), secondary: Color(red: 0.72, green: 0.78, blue: 0.74), fontDesign: .monospaced)
        }
    }

    static func selected(_ rawValue: String) -> ClockinThemeChoice {
        ClockinThemeChoice(rawValue: rawValue) ?? .carbon
    }
}

struct ClockinPalette {
    let background: Color
    let accent: Color
    let secondary: Color
    let fontDesign: Font.Design
}
