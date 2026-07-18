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
    static let appLargeNumeric  = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let appMedNumeric    = Font.system(.title, design: .rounded, weight: .bold)
    static let appSmallNumeric  = Font.system(.title3, design: .rounded, weight: .bold)
    static let appTitle         = Font.system(.title2, design: .default, weight: .semibold)
    static let appHeadline      = Font.system(.title3, design: .default, weight: .semibold)
    static let appSubheadline   = Font.system(.subheadline, design: .default, weight: .medium)
    static let appBody          = Font.system(.body, design: .default, weight: .regular)
    static let appCaption       = Font.system(.caption, design: .default, weight: .regular)
}
