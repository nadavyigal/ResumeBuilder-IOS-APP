# Hebrew (עברית) App Store Listing — Resumely iOS

Source of truth for the Hebrew copy is the web repo
(`new-ResumeBuilder-ai-/launch-assets/aso/he-metadata.md`, PR #65). This file
mirrors it for the iOS submission and adds the App Store Connect steps and the
Hebrew screenshot procedure. Keep both in sync if the copy changes.

> These are App Store Connect actions (manual). No fastlane dependency is added
> to this repo. If you later want `fastlane deliver` for repeatability, flag it
> first per the repo's no-new-dependency rule.

## App Store Connect — add Hebrew localization

In App Store Connect → App → Distribution → (version) → add language **Hebrew**,
then paste the fields below. Israeli App Store territory should already be on.

### Name / Title (30 chars max)
```
Resumely: בונה קורות חיים
```
(24 chars)

### Subtitle (30 chars max)
```
קורות חיים מותאמים לכל משרה
```
(28 chars)

### Keywords (100 chars max)

Proposed 2026-11-21 (draft, not in App Store Connect). Single words, commas, no
spaces, no word already in the Hebrew name or subtitle. The live Hebrew name and
subtitle are not confirmed yet (founder to paste them).

If the live Hebrew name or subtitle contains "קורות חיים":
```
משרה,עבודה,מועמדות,מכתב,מקדים,התאמה,ציון,מגייס,ראיון,קריירה,לינקדאין,כתיבת,שכתוב,רזומה
```
(86 chars)

If it does not:
```
קורות,חיים,משרה,עבודה,מועמדות,מכתב,מקדים,התאמה,ציון,מגייס,ראיון,קריירה,לינקדאין,רזומה
```
(85 chars)

Check the counter in App Store Connect after pasting: some guides say the limit is
100 bytes, and Hebrew letters take 2 bytes each in UTF-8 (these lines are about
160 bytes). If the field refuses it, drop words from the end until it fits.

Previous draft (replaced; multi-word phrases and repeats of the name):
```
קורות חיים,בקשת עבודה,ATS,מחפש עבודה,כתיבת קורות חיים,ייעול קורות חיים,מכתב מקדים
```
(84 chars)

### Promotional Text (170 chars max)
```
בדוק התאמה לפני ההגשה. Resumely מראה מה חסר, עוזרת להתאים קורות חיים ומייצאת חבילת מועמדות מהאייפון.
```

### Description (4000 chars max)
```
Resumely משתמשת בבינה מלאכותית כדי לבדוק התאמה למשרה, להתאים את קורות החיים שלך ולייצא חבילת מועמדות מהאייפון — ללא כתיבה מחדש, ללא ניחושים.

איך זה עובד
1. העלה את קורות החיים שלך (PDF או Word)
2. הדבק את תיאור המשרה או קישור למשרה
3. Resumely מנתחת את דרישות המשרה, מציגה מה חסר ומשפרת כל סעיף
4. ראה את ציון ההתאמה שלך ב-Resumely עולה — ואז ייצא PDF מותאם לחלוטין

למה זה עובד
קורות חיים כלליים מקשים לדעת אם המשרה באמת מתאימה לך. Resumely בודקת התאמה מול תיאור המשרה, מזהה פערי מילות מפתח ומבנה, ומציעה תיקונים ממוקדים בלי להבטיח תוצאה מול מערכת גיוס מסוימת.

מה מקבלים — בחינם
• 1 אופטימיזציה מלאה של AI
• ציון התאמה של Resumely עם פערי מילות מפתח
• ייצוא PDF וחבילת מועמדות

שדרוג לעוד
• תמחור ושדרוגים ייקבעו אחרי קריאת נתוני הפעלה ושימוש אמיתיים

מצבי מומחה (ללא הגבלה)
• יצירת מכתב מקדים
• הכנה לראיון עבודה
• אופטימיזציה של פרופיל LinkedIn
• מדריך למשא ומתן על שכר

פרטיות: קורות החיים שלך מגובבים ולא נשמרים בצורה קריאה. אנחנו לא מוכרים את הנתונים שלך.

נבנה על ידי מייסד בודד שבזבז יותר מדי זמן על התאמה ידנית של קורות חיים לכל מועמדות.
```

## Hebrew screenshots

The marketing screenshots are produced by the launch-argument-only
`MarketingScreenshotView` (`--marketing-screenshot --screenshot-slot N`). To
capture the Hebrew set, launch each slot with the app forced to Hebrew so the
localized strings and RTL layout render. Add the language args to the launch in
`scripts/generate-app-store-screenshots.sh` (line ~60), or run manually:

```sh
xcrun simctl launch "$DEVICE" Resumebuilder-IOS.ResumeBuilder-IOS-APP \
  --marketing-screenshot --screenshot-slot "$SLOT" \
  -AppleLanguages "(he)" -AppleLocale he_IL
```

Save the Hebrew set under a separate folder (e.g.
`dist/app-store-screenshots/he/`) and upload to the Hebrew localization in App
Store Connect. Note: any English text still inside `MarketingScreenshotView`
that is passed as a plain `String` (not `Text("literal")` / `LocalizedStringKey`)
will not translate — audit that view before capturing if a fully-Hebrew set is
required (same `LocalizedStringKey` treatment used in the core-flow sweep).

## Submission checklist (manual, App Store Connect)
- [ ] Add Hebrew localization to the current version; paste fields above.
- [ ] Confirm Israel is in the app's available territories.
- [ ] Capture + upload Hebrew screenshots (6.5" iPhone + 13" iPad).
- [ ] Preview the Hebrew listing in App Store Connect before submitting.
- [ ] Submit for review.
