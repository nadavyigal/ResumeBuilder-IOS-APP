# TestFlight Readiness Report

**Date:** YYYY-MM-DD
**Version:** [Marketing version, e.g. 1.0]
**Build:** [Build number, e.g. 2]
**Reviewer:** [Agent / Nadav]
**Result:** READY | NOT READY | CONDITIONAL

---

## Summary
_One paragraph: overall readiness, blockers, recommendation._

## Prerequisites
- iOS QA Checklist: ✅ Passed (see `docs/qa/reports/ios-qa-[date].md`) | ❌ Not completed

## Build & Signing
| Check | Result | Notes |
|-------|--------|-------|
| Archive succeeds | ✅/❌ | |
| Bundle ID correct | ✅/❌ | `Resumebuilder-IOS.ResumeBuilder-IOS-APP` |
| Signing team correct | ✅/❌ | |
| Provisioning profile valid | ✅/❌ | |

## Entitlements
| Entitlement | Result | Notes |
|-------------|--------|-------|
| com.apple.developer.applesignin | ✅/❌ | |
| Push (if active) | ✅/❌/N/A | |

## Info.plist
| Check | Result | Notes |
|-------|--------|-------|
| API_BASE_URL set (not localhost) | ✅/❌ | Value: [URL] |
| Marketing version correct | ✅/❌ | Value: [version] |
| Build number incremented | ✅/❌ | Value: [build] |
| Privacy strings present | ✅/❌/N/A | |

## App Icon & Launch Screen
| Check | Result | Notes |
|-------|--------|-------|
| All icon slots filled | ✅/❌ | |
| Launch screen correct | ✅/❌ | |

## Core Flow Smoke Test (Real Device)
| Flow | Result | Notes |
|------|--------|-------|
| Cold launch | ✅/❌ | |
| Sign in with Apple | ✅/❌ | |
| Upload resume | ✅/❌ | |
| ATS score | ✅/❌ | |
| Optimization | ✅/❌ | |
| PDF export | ✅/❌ | |
| Sign out | ✅/❌ | |

## Data / Privacy
| Check | Result | Notes |
|-------|--------|-------|
| No test tokens in binary | ✅/❌ | |
| API points to production | ✅/❌ | |
| No debug UI in release | ✅/❌ | |

## Known Issues for TestFlight Notes
_List issues that testers should be aware of._

## Recommendation
- [ ] Upload to TestFlight — ready
- [ ] Fix blockers first: [list]
- [ ] Accepted known issues: [list]
