import SwiftUI

/// Copy for the Home/onboarding upload card.
///
/// These are `LocalizedStringKey`, never `String`. The app switches language at
/// runtime through `LocalizationManager` (`Bundle.setAppLanguage` plus
/// `.environment(\.locale, …)` at the app root). A `LocalizedStringKey` is
/// resolved by SwiftUI at render time against that environment, so it follows a
/// live HE/EN switch. `NSLocalizedString` resolves eagerly during body
/// evaluation and freezes the value: if the enclosing body is not re-evaluated
/// on the switch, the previous language's text stays on screen — which is how
/// the Hebrew subtitle leaked into the English upload card.
enum UploadCardCopy {
    /// Shown under the card title when no résumé has been picked yet.
    static let subtitle: LocalizedStringKey = "PDF or DOCX · up to 5 MB"

    /// VoiceOver label for the card in its empty state.
    static let uploadAccessibilityLabel: LocalizedStringKey =
        "Upload your résumé. PDF or DOCX up to 5 megabytes."

    /// VoiceOver label for the card once a résumé has been picked.
    static let selectedAccessibilityLabel: LocalizedStringKey =
        "Résumé selected. Choose a different file."
}
