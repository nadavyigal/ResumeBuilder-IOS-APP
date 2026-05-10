import SwiftUI

enum AppTypography {
    // Large score numerals — SF Pro Rounded
    static func numeric(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    // Headings — SF Pro Display-ish (semibold, tight tracking)
    static func heading(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }

    // Body / labels
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}

extension Font {
    static let appLargeNumeric  = AppTypography.numeric(64)
    static let appMedNumeric    = AppTypography.numeric(32)
    static let appSmallNumeric  = AppTypography.numeric(20)
    static let appTitle         = AppTypography.heading(28)
    static let appHeadline      = AppTypography.heading(20)
    static let appSubheadline   = AppTypography.body(15, weight: .medium)
    static let appBody          = AppTypography.body(15)
    static let appCaption       = AppTypography.body(12)
}
