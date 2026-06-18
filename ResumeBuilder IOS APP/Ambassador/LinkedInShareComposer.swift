// ResumeBuilder IOS APP/Ambassador/LinkedInShareComposer.swift
// Plan 4: Ambassador Flow — builds pre-drafted LinkedIn post with user's ATS score data
//
// SKELETON — implement when gate opens.
//
// Architecture:
//   - makeActivityController(atsScoreBefore:atsScoreAfter:jobTitle:locale:) → UIActivityViewController
//   - User can edit text before sharing (standard UIActivityViewController behaviour)
//   - Locale from device or user preference: 'en' or 'he'
//   - ATS scores substituted from actual data stored at export time

import UIKit

enum LinkedInShareComposer {

    static let appStoreURL = "https://apps.apple.com/app/resumely/id000000000"
    // Replace id000000000 with real App Store ID when live.

    static func makeActivityController(
        atsScoreBefore: Int,
        atsScoreAfter: Int,
        jobTitle: String?,
        locale: String
    ) -> UIActivityViewController {
        let text = draftPost(
            atsScoreBefore: atsScoreBefore,
            atsScoreAfter: atsScoreAfter,
            jobTitle: jobTitle,
            locale: locale
        )
        return UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }

    static func draftPost(atsScoreBefore: Int, atsScoreAfter: Int, jobTitle: String?, locale: String) -> String {
        // TODO: substitute real job title into the template when available
        if locale == "he" {
            return """
            שמח לשתף שנקראתי לראיון\(jobTitle.map { " ב-\($0)" } ?? "") 🎉

            השתמשתי ב-Resumely כדי להתאים את קורות החיים שלי למשרה —
            הציון ATS קפץ מ-\(atsScoreBefore) ל-\(atsScoreAfter). לקח 5 דקות בנייד.

            למי שמחפש עבודה, שווה לנסות 👇
            \(appStoreURL)

            #חיפוש_עבודה #קורות_חיים
            """
        } else {
            return """
            Excited to share that I just landed an interview\(jobTitle.map { " at \($0)" } ?? "") 🎉

            Used Resumely to tailor my resume to the job description — ATS score jumped
            from \(atsScoreBefore) → \(atsScoreAfter). The optimisation took 5 minutes on my phone.

            If you're job hunting, give it a try 👇
            \(appStoreURL)

            #JobSearch #Resume #CareerTips
            """
        }
    }
}
