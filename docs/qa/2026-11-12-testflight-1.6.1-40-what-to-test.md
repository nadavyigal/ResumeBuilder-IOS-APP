# Resumely 1.6.1 (40): TestFlight "What to Test"

Paste the block below into App Store Connect > TestFlight > build 40 > Test Details.

```
Run a check with a résumé and a job, then open the Optimized tab.

- The résumé shows as a half page with "View full resume". The match score estimate is visible above the export button without scrolling. Swiping on the résumé scrolls the screen.
- "View full resume" opens the whole résumé. "Done" closes it.
- "See what changed" sits above the résumé. Its screen ends with "Back to my résumé".
- Under the score, "Before you send" lists Improve match, Add a cover letter and Choose a design. A finished step gets a check mark.
- "Improve match" runs a second pass, then shows "Done. Your résumé and score are updated."
- The export button reads "Export résumé", or "Export application package" once you have a cover letter.
- Exported PDF: no "Not specified" text, and no stray "|" or "," where a field is empty.
- Expert tab: Cover Letter is first, Resume Rewrite is last.
- Go back to Home and tap "Check my fit" again with the same file and job. It should open the existing result without a new long check.
- Sign-in: "Forgot password?" sends a reset email. Me: "Change Password" works.
- After a PDF download, the count on Me goes down without a relaunch.
- Repeat the main screens with the app in Hebrew.
```
