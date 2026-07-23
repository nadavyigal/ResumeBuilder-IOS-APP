# Optimization ID Preservation (WP-53) Implementation Plan

> **Codex review amendment — 2026-07-23:** Execute Task 1 only. A thrown history
> request is non-authoritative and
> must preserve the persisted ID. A successful history response containing no
> recoverable item remains authoritative; retaining the ID in that case could
> unlock tabs with an optimization that was deleted or belongs to stale local
> state. Task 3 is also unnecessary: the existing 200-response rejection branch
> already surfaces the server message, emits exactly one failure event, leaves
> `applySuccessOptimizationId` nil, and therefore neither navigates nor reports
> visible success. Add a regression test for that contract instead of moving the
> same handling through a thrown error. Extend the already-compiled
> `FirstSessionJourneyTests.swift` and `ResumeOptimizationParsingTests.swift`
> rather than creating new test files and manually editing test-target
> membership. Baseline is 208 XCTest + 5 Swift Testing tests, not the older
> 207-test figure below.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop `AppState` from permanently destroying the user's `latestOptimizationId` when the optimization-history fetch fails, so a transient network error no longer orphans a completed optimization and locks the user out of the preview and export path.

**Architecture (amended):** `reconcileLatestOptimization()` currently clears `latestOptimizationId` *before* its network call and only restores it on the success paths. Because the property's setter also writes through to `UserDefaults`, the clear is persistent, not just in-memory. The approved fix removes the speculative clear and restores the captured ID explicitly on the failure path. Successful history responses remain authoritative. The existing backend apply-rejection behavior remains unchanged and is regression-tested.

**Tech Stack:** Swift 5.9+, SwiftUI, `@Observable` AppState, XCTest, Xcode project (no SPM manifest for the app target).

## Global Constraints

- Test runtime must be the **iOS 26.5** simulator. On 26.3.1 the XCTest host aborts with `malloc: pointer being freed was not allocated` (`tasks/lessons.md:53`).
- Use a derived-data path under `/private/tmp`, never the default inside `~/Documents` (iCloud xattrs cause CodeSign "detritus" failures).
- The full suite intermittently crashes the test *host* at a fixed address in a varying test (`tasks/lessons.md:158`). That is pre-existing and not a regression. Confirm every suite reports 0 failures and the total count matches baseline before treating `** TEST FAILED **` as real.
- No new dependencies. No `npm install`, no SPM additions.
- Do not change any analytics event *name* or existing property *value*. Diagnostics continuity matters: `optimization_state_recovery_failed` must keep emitting `reason` / `error_code`, and a backend apply rejection must keep emitting exactly `reason: "backend_rejected"`, `error_code: "backend_error"`.
- Exactly one `optimization_apply_failed` event per failed apply attempt. Double-tracking is a regression.
- Update `tasks/progress.md` after every commit (Status, Current Phase, Active Story, Last Completed Story, Next Recommended Story, Blockers, Last Validation, Last Updated).

---

## Background: what the evidence actually says

Read this before touching code. It corrects a natural but wrong assumption.

**`optimized_preview_rendered` not firing is ALREADY FIXED.** Commit `39654f1` (WP-51, 2026-07-21) found that the event was gated on `hasVisibleAppliedChanges`, which reads the separately fetched `sections` array. The preview's primary path renders from `optimization_id` alone, so `sections` was empty while a real resume was on screen. That fix shipped in 1.4.5 and is **confirmed working live**: the 2026-07-22 session on 1.4.5 emitted the full chain `optimized_preview_rendered` → `optimized_viewed` → `export_cta_seen` → `export_pdf_tapped` → `export_started` → `export_success`. Do not re-fix this.

**What is still broken** is upstream of the preview: the app throws away the id that the preview needs.

PostHog failure diagnostics, last 21 days, by `error_code`:

| event | error_code | meaning | versions |
|---|---|---|---|
| `optimization_state_recovery_failed` | `network_1004` | `NSURLErrorCannotConnectToHost` | 1.4.2, 1.4.3, 1.4.4, 1.4.5 |
| `save_failed` | `network_1009` | `NSURLErrorNotConnectedToInternet` | 1.4.1–1.4.5 |
| `optimization_apply_failed` | `server_503` | backend unavailable | 1.4.2, 1.4.3, 1.4.4, 1.4.5 |

`optimization_state_recovery_failed` fired for **9 of the 12** users who completed an optimization and never reached the export CTA.

**Caveat, stated honestly:** a meaningful share of the 1.4.5 failure events (the 2026-07-22 04:40–04:42 cluster) come from automated burst traffic running offline, so the *rate* is inflated. The `server_503` apply failures on 1.4.2 (7 distinct people) are not burst-shaped and look like genuine backend unavailability. Treat the failure *mechanism* as proven and the failure *frequency* as unmeasured.

**The causal chain:**

```
history fetch throws (network_1004)
  → AppState.swift:302 already niled latestOptimizationId (+ removed the UserDefaults key)
  → catch block at :330 never restores it
  → OptimizedResumeTabView.syncVM() guard at :36 fails → optimizedVM = nil
  → renders LockedTabTeaser ("Here's what you'll unlock")
  → OptimizedResumeView never mounts
  → optimized_preview_rendered / optimized_viewed / export_cta_seen / saved_resume_prompt_viewed never fire
  → no export → no activation
```

`reconcileLatestOptimization()` runs from `bootstrapAndRefreshSession()` (`AppState.swift:130`) on **every cold launch**, so one bad launch permanently orphans the optimization. The user's completed work looks deleted.

**Out of scope for this plan:** the `server_503` origin lives in the ResumeBuilder **web/backend** repo, not this one. `OptimizationReviewView.swift:174` already special-cases a 503 whose body contains `operation_type` as "server needs a database update", which suggests a pending backend migration. File that separately against the web repo; this plan only stops the *client* from destroying state when the server misbehaves.

---

## File Structure

| File | Responsibility | Change |
|---|---|---|
| `ResumeBuilder IOS APP/App/AppState.swift` | Owns `latestOptimizationId` + recovery lifecycle | Modify `reconcileLatestOptimization()` (lines 287–340) |
| `ResumeBuilder IOS APP/Core/Export/ResumeExportAction.swift` | Maps errors → analytics `reason` / `error_code` | Add one case to each mapper |
| `ResumeBuilder IOS APP/Features/V2/History/OptimizationReviewView.swift` | Review + apply flow | Make backend rejection throw instead of return |
| `ResumeBuilder IOS APPTests/AppStateRecoveryTests.swift` | **New.** Recovery-path regression tests | Create |
| `ResumeBuilder IOS APPTests/OptimizationReviewApplyTests.swift` | **New.** Apply-rejection control-flow test | Create |

Tests go in new files rather than `AppStateRefreshTests.swift` so a failure name points straight at the recovery contract.

---

### Task 1: Preserve the optimization id across a recovery failure

This is the primary fix and carries most of the expected activation impact.

**Files:**
- Modify: `ResumeBuilder IOS APP/App/AppState.swift:300-339`
- Test: `ResumeBuilder IOS APPTests/AppStateRecoveryTests.swift` (create)

**Interfaces:**
- Consumes: `AppState.init(optimizationHistoryService:)`, `OptimizationHistoryServiceProtocol.list(token:)`, `AppState.latestOptimizationId`, `AppState.optimizationRecoveryState`, `AppState.session`.
- Produces: the invariant **"a thrown history fetch never mutates `latestOptimizationId`"**, relied on by Task 2.

- [ ] **Step 1: Write the failing test**

Create `ResumeBuilder IOS APPTests/AppStateRecoveryTests.swift`:

```swift
import XCTest
@testable import ResumeBuilder_IOS_APP

@MainActor
final class AppStateRecoveryTests: XCTestCase {

    /// Fails every history fetch the way the field failure does (NSURLErrorCannotConnectToHost
    /// == error_code "network_1004" in PostHog).
    private struct UnreachableHistoryService: OptimizationHistoryServiceProtocol {
        func list(token: String) async throws -> [OptimizationHistoryItem] {
            throw URLError(.cannotConnectToHost)
        }
        func delete(ids: [String], token: String) async throws -> BulkDeleteResponse {
            throw URLError(.cannotConnectToHost)
        }
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: AppState.latestOptimizationKey)
        super.tearDown()
    }

    private func authenticated(_ appState: AppState) {
        appState.session = AuthSession(
            accessToken: "access-token",
            refreshToken: "refresh-token",
            userId: "user-1",
            email: nil
        )
    }

    func testRecoveryFailureKeepsLocalOptimizationIdInMemory() async {
        let appState = AppState(optimizationHistoryService: UnreachableHistoryService())
        authenticated(appState)
        appState.latestOptimizationId = "opt-123"

        await appState.reconcileLatestOptimization()

        XCTAssertEqual(
            appState.latestOptimizationId,
            "opt-123",
            "A transient history-fetch failure must not discard the user's optimization id"
        )
        XCTAssertEqual(appState.optimizationRecoveryState, .failed)
    }

    func testRecoveryFailureKeepsLocalOptimizationIdOnDisk() async {
        let appState = AppState(optimizationHistoryService: UnreachableHistoryService())
        authenticated(appState)
        appState.latestOptimizationId = "opt-123"

        await appState.reconcileLatestOptimization()

        XCTAssertEqual(
            UserDefaults.standard.string(forKey: AppState.latestOptimizationKey),
            "opt-123",
            "The id must survive relaunch; the setter writes through to UserDefaults"
        )
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
xcodebuild test -project "ResumeBuilder IOS APP.xcodeproj" -scheme "ResumeBuilder IOS APP" -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -derivedDataPath /private/tmp/rb-ios-dd -only-testing:"ResumeBuilder IOS APPTests/AppStateRecoveryTests"
```

Expected: both tests FAIL. `testRecoveryFailureKeepsLocalOptimizationIdInMemory` reports `XCTAssertEqual failed: ("nil") is not equal to ("Optional("opt-123")")`. This red state is required evidence: it proves the test reaches the defect.

If instead you get a compile error about `AppState.latestOptimizationKey` being inaccessible, confirm it is declared `nonisolated static let` (not `private`) near `AppState.swift:74`. If it is private, widen it to internal in this same step and note it in the commit body.

- [ ] **Step 3: Apply the minimal fix**

In `ResumeBuilder IOS APP/App/AppState.swift`, find this block (starts at line 300):

```swift
        let localOptimizationId = latestOptimizationId
        optimizationRecoveryState = .loading
        latestOptimizationId = nil
        latestOptimization = nil
```

Replace it with:

```swift
        let localOptimizationId = latestOptimizationId
        optimizationRecoveryState = .loading
        // Do NOT clear `latestOptimizationId` speculatively. Its setter writes through to
        // UserDefaults, so clearing here made a transient fetch failure destroy the user's
        // optimization permanently — the Optimized tab then rendered LockedTabTeaser as if
        // they had never optimized (WP-53). Only the authoritative-empty branch below and
        // signOut() may clear it. `latestOptimization` is still dropped so the detail object
        // is refetched rather than served stale.
        latestOptimization = nil
```

Then find the `catch` block (starts at line 330):

```swift
        } catch {
            latestOptimization = nil
            optimizationRecoveryState = .failed
            AnalyticsService.shared.track(
                .optimizationStateRecoveryFailed(
                    reason: FailureReason.reason(for: error),
                    errorCode: ExportFailureCode.code(for: error)
                )
            )
        }
```

Replace it with:

```swift
        } catch {
            // Defense in depth: the speculative clear above is gone, but restate the invariant
            // so any future edit that reintroduces a clear still cannot strand the user.
            latestOptimizationId = localOptimizationId
            latestOptimization = nil
            optimizationRecoveryState = .failed
            AnalyticsService.shared.track(
                .optimizationStateRecoveryFailed(
                    reason: FailureReason.reason(for: error),
                    errorCode: ExportFailureCode.code(for: error)
                )
            )
        }
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
xcodebuild test -project "ResumeBuilder IOS APP.xcodeproj" -scheme "ResumeBuilder IOS APP" -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -derivedDataPath /private/tmp/rb-ios-dd -only-testing:"ResumeBuilder IOS APPTests/AppStateRecoveryTests"
```

Expected: PASS, 2 tests, 0 failures.

- [ ] **Step 5: Run the neighbouring suites for regressions**

```bash
xcodebuild test -project "ResumeBuilder IOS APP.xcodeproj" -scheme "ResumeBuilder IOS APP" -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -derivedDataPath /private/tmp/rb-ios-dd -only-testing:"ResumeBuilder IOS APPTests/AppStateRefreshTests" -only-testing:"ResumeBuilder IOS APPTests/OptimizedResumeViewModelTests" -only-testing:"ResumeBuilder IOS APPTests/OptimizationDetailCacheTests"
```

Expected: PASS, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add "ResumeBuilder IOS APP/App/AppState.swift" "ResumeBuilder IOS APPTests/AppStateRecoveryTests.swift" tasks/progress.md
git commit -m "fix(ios): stop recovery failure from destroying latestOptimizationId (WP-53)"
```

---

### Task 2: Rejected during review — keep successful history responses authoritative

**Files:**
- Modify: `ResumeBuilder IOS APP/App/AppState.swift:319-324`
- Test: `ResumeBuilder IOS APPTests/AppStateRecoveryTests.swift` (extend)

**Interfaces:**
- Consumes: the Task 1 invariant, `AppState.isRecoverableOptimization`, `OptimizationHistoryItem`.
- Produces: no new API surface.

**Why this matters:** `isRecoverableOptimization` (`AppState.swift:474`) requires `status` to lowercase-trim to exactly `"completed"`. Any backend status drift (`"applied"`, `"complete"`, a paginated list that omits the newest row) makes `completed` empty, and the current code then nils a perfectly usable local id. Per the WP-51 finding, the preview renders from `optimization_id` alone and does not need the history list at all, so keeping the id is both safe and sufficient to render.

- [ ] **Step 1: Write the failing test**

Append inside `AppStateRecoveryTests`:

```swift
    /// Returns a history list that contains no item passing `isRecoverableOptimization`,
    /// simulating backend status drift or a paginated list missing the newest row.
    private struct EmptyHistoryService: OptimizationHistoryServiceProtocol {
        func list(token: String) async throws -> [OptimizationHistoryItem] {
            [
                OptimizationHistoryItem(
                    id: "opt-123",
                    createdAt: "2026-07-22T10:00:00Z",
                    jobTitle: nil,
                    company: nil,
                    matchScorePercent: 70,
                    contentScorePercent: nil,
                    designScorePercent: nil,
                    keywordScorePercent: nil,
                    status: "applied",
                    jobUrl: nil,
                    templateKey: nil,
                    resumeId: nil,
                    reviewId: nil
                )
            ]
        }
        func delete(ids: [String], token: String) async throws -> BulkDeleteResponse {
            throw URLError(.cannotConnectToHost)
        }
    }

    func testUnrecognizedServerStatusDoesNotDiscardLocalOptimizationId() async {
        let appState = AppState(optimizationHistoryService: EmptyHistoryService())
        authenticated(appState)
        appState.latestOptimizationId = "opt-123"

        await appState.reconcileLatestOptimization()

        XCTAssertEqual(
            appState.latestOptimizationId,
            "opt-123",
            "A status the client does not recognize must not delete the user's optimization"
        )
    }

    func testEmptyHistoryWithNoLocalIdStillReportsEmpty() async {
        let appState = AppState(optimizationHistoryService: EmptyHistoryService())
        authenticated(appState)
        appState.latestOptimizationId = nil

        await appState.reconcileLatestOptimization()

        XCTAssertNil(appState.latestOptimizationId)
        XCTAssertEqual(appState.optimizationRecoveryState, .empty)
    }
```

If the `OptimizationHistoryItem` memberwise init rejects this call, open `ResumeBuilder IOS APP/Core/API/Models/DomainModels.swift:440` and match the declared parameter order exactly. Do not add a convenience init.

- [ ] **Step 2: Run to verify it fails**

```bash
xcodebuild test -project "ResumeBuilder IOS APP.xcodeproj" -scheme "ResumeBuilder IOS APP" -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -derivedDataPath /private/tmp/rb-ios-dd -only-testing:"ResumeBuilder IOS APPTests/AppStateRecoveryTests/testUnrecognizedServerStatusDoesNotDiscardLocalOptimizationId"
```

Expected: FAIL — `("nil") is not equal to ("Optional("opt-123")")`.

- [ ] **Step 3: Apply the fix**

In `AppState.swift`, find:

```swift
            guard let recovered = completed.max(by: { $0.createdAt < $1.createdAt }) else {
                latestOptimizationId = nil
                latestOptimization = nil
                optimizationRecoveryState = .empty
                return
            }
```

Replace with:

```swift
            guard let recovered = completed.max(by: { $0.createdAt < $1.createdAt }) else {
                // The server returned nothing this client recognizes as recoverable. That is not
                // proof the user's optimization is gone — `isRecoverableOptimization` demands an
                // exact "completed" status, so any backend status drift lands here. The preview
                // renders from optimization_id alone (WP-51), so a local id stays usable; keep it
                // and report .ready. Only clear when there was no local id to begin with.
                latestOptimization = nil
                if let localOptimizationId {
                    latestOptimizationId = localOptimizationId
                    optimizationRecoveryState = .ready
                } else {
                    latestOptimizationId = nil
                    optimizationRecoveryState = .empty
                }
                return
            }
```

- [ ] **Step 4: Run to verify it passes**

```bash
xcodebuild test -project "ResumeBuilder IOS APP.xcodeproj" -scheme "ResumeBuilder IOS APP" -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -derivedDataPath /private/tmp/rb-ios-dd -only-testing:"ResumeBuilder IOS APPTests/AppStateRecoveryTests"
```

Expected: PASS, 4 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add "ResumeBuilder IOS APP/App/AppState.swift" "ResumeBuilder IOS APPTests/AppStateRecoveryTests.swift" tasks/progress.md
git commit -m "fix(ios): keep local optimization id when server history has no recognized status (WP-53)"
```

---

### Task 3: Rejected during review — regression-test the existing rejection behavior

**Files:**
- Modify: `ResumeBuilder IOS APP/Core/Export/ResumeExportAction.swift` (both mappers)
- Modify: `ResumeBuilder IOS APP/Features/V2/History/OptimizationReviewView.swift:232-259`
- Test: `ResumeBuilder IOS APPTests/OptimizationReviewApplyTests.swift` (create)

**Interfaces:**
- Consumes: `FailureReason.reason(for:)`, `ExportFailureCode.code(for:)`.
- Produces: `enum OptimizationReviewApplyError: Error { case backendRejected(String) }`, mapping to `reason: "backend_rejected"` and `error_code: "backend_error"`.

**Why:** `apply(with:)` currently tracks `optimization_apply_failed` inline and then `return`s **normally**. `applyOrRecover` therefore reports success, the caller's `catch` never runs, `recoverAppliedState` never gets its chance, and `applySuccessOptimizationId` stays nil — so `handleAppliedOptimization` never sets `appState.latestOptimizationId` and the user never navigates to the preview. Throwing routes it through the existing recovery-and-error path. Moving the tracking to the caller's `catch` keeps exactly one event per failure.

- [ ] **Step 1: Write the failing test**

Create `ResumeBuilder IOS APPTests/OptimizationReviewApplyTests.swift`:

```swift
import XCTest
@testable import ResumeBuilder_IOS_APP

final class OptimizationReviewApplyTests: XCTestCase {

    func testBackendRejectionMapsToStableAnalyticsReason() {
        let error = OptimizationReviewApplyError.backendRejected("no credits")
        XCTAssertEqual(FailureReason.reason(for: error), "backend_rejected")
    }

    func testBackendRejectionMapsToStableAnalyticsErrorCode() {
        let error = OptimizationReviewApplyError.backendRejected("no credits")
        XCTAssertEqual(ExportFailureCode.code(for: error), "backend_error")
    }

    func testBackendRejectionCarriesServerMessage() {
        let error = OptimizationReviewApplyError.backendRejected("no credits")
        guard case .backendRejected(let message) = error else {
            return XCTFail("Expected .backendRejected")
        }
        XCTAssertEqual(message, "no credits")
    }
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
xcodebuild test -project "ResumeBuilder IOS APP.xcodeproj" -scheme "ResumeBuilder IOS APP" -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -derivedDataPath /private/tmp/rb-ios-dd -only-testing:"ResumeBuilder IOS APPTests/OptimizationReviewApplyTests"
```

Expected: FAIL to compile — `cannot find 'OptimizationReviewApplyError' in scope`. That is valid red state.

- [ ] **Step 3: Add the error type and its mappings**

In `ResumeBuilder IOS APP/Core/Export/ResumeExportAction.swift`, add above `enum ExportFailureCode` (line 50):

```swift
/// A review-apply call the backend answered with an error body rather than an HTTP failure.
enum OptimizationReviewApplyError: Error {
    case backendRejected(String)
}
```

In `ExportFailureCode.code(for:)`, insert immediately after the `APIClientError` block closes (after line 60):

```swift
        if case OptimizationReviewApplyError.backendRejected = error { return "backend_error" }
```

In `FailureReason.reason(for:)`, insert immediately after its `APIClientError` block closes (after line 92):

```swift
        if case OptimizationReviewApplyError.backendRejected = error { return "backend_rejected" }
```

- [ ] **Step 4: Run to verify the mapping tests pass**

```bash
xcodebuild test -project "ResumeBuilder IOS APP.xcodeproj" -scheme "ResumeBuilder IOS APP" -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -derivedDataPath /private/tmp/rb-ios-dd -only-testing:"ResumeBuilder IOS APPTests/OptimizationReviewApplyTests"
```

Expected: PASS, 3 tests, 0 failures.

- [ ] **Step 5: Make the apply path throw**

In `ResumeBuilder IOS APP/Features/V2/History/OptimizationReviewView.swift`, find (line 240):

```swift
        if let err = result.error, result.optimizationId == nil {
            errorMessage = err
            AnalyticsService.shared.track(
                .optimizationApplyFailed(
                    reviewId: reviewId,
                    reason: "backend_rejected",
                    errorCode: "backend_error"
                )
            )
            return
        }
```

Replace with:

```swift
        if let err = result.error, result.optimizationId == nil {
            // Throw rather than return: returning normally made `applyOrRecover` report success,
            // so the caller never ran its catch, `recoverAppliedState` never got a chance, and
            // applySuccessOptimizationId stayed nil — the user sat on the review screen and never
            // reached the preview (WP-53). Tracking moves to the caller's catch so a failed apply
            // still emits exactly one optimization_apply_failed.
            throw OptimizationReviewApplyError.backendRejected(err)
        }
```

- [ ] **Step 6: Surface the server message in the caller**

Both `apply(token:)` and `apply(appState:)` end with a generic `catch` that sets `errorMessage = error.localizedDescription`. `OptimizationReviewApplyError` has no `errorDescription`, so that would show an opaque string. In **both** functions, replace the final generic catch:

```swift
        } catch {
            trackApplyFailure(error)
            errorMessage = error.localizedDescription
        }
```

with:

```swift
        } catch let applyError as OptimizationReviewApplyError {
            trackApplyFailure(applyError)
            if case .backendRejected(let message) = applyError {
                errorMessage = message
            }
        } catch {
            trackApplyFailure(error)
            errorMessage = error.localizedDescription
        }
```

- [ ] **Step 7: Verify `recoverAppliedState` still declines this error**

Read `recoverAppliedState(after:token:)` at line 272. Its first line is:

```swift
        guard Self.isTimeout(error) || Self.isAlreadyApplied(error) else { return false }
```

`OptimizationReviewApplyError.backendRejected` is neither a timeout nor an already-applied error, so it returns `false` and `applyOrRecover` rethrows. That is the intended behaviour: a genuine backend rejection should reach the user, not be silently recovered. **No code change in this step** — confirm by reading, and confirm `isAlreadyApplied(_:)` does not pattern-match arbitrary errors.

- [ ] **Step 8: Run the full apply-related suites**

```bash
xcodebuild test -project "ResumeBuilder IOS APP.xcodeproj" -scheme "ResumeBuilder IOS APP" -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -derivedDataPath /private/tmp/rb-ios-dd -only-testing:"ResumeBuilder IOS APPTests/OptimizationReviewApplyTests" -only-testing:"ResumeBuilder IOS APPTests/AnalyticsServiceTests" -only-testing:"ResumeBuilder IOS APPTests/AppStateRecoveryTests"
```

Expected: PASS, 0 failures.

- [ ] **Step 9: Commit**

```bash
git add "ResumeBuilder IOS APP/Core/Export/ResumeExportAction.swift" "ResumeBuilder IOS APP/Features/V2/History/OptimizationReviewView.swift" "ResumeBuilder IOS APPTests/OptimizationReviewApplyTests.swift" tasks/progress.md
git commit -m "fix(ios): propagate backend apply rejection instead of returning success (WP-53)"
```

---

### Task 4: Full-suite verification, lessons, and ship

**Files:**
- Modify: `tasks/lessons.md`, `tasks/progress.md`, `tasks/session-log.md`

- [ ] **Step 1: Full suite**

```bash
xcodebuild test -project "ResumeBuilder IOS APP.xcodeproj" -scheme "ResumeBuilder IOS APP" -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -derivedDataPath /private/tmp/rb-ios-dd
```

Expected: baseline is **207 tests / 1 intentional skip / 0 failures**, plus the 7 tests added here = **214 / 1 skip / 0 failures**. If it ends `** TEST FAILED **` with an empty "Failing tests:" list and a `malloc: pointer being freed was not allocated` message, that is the known host-teardown crash (`tasks/lessons.md:158`) — confirm each suite reported 0 failures and rerun before treating it as a regression.

- [ ] **Step 2: Release build**

```bash
xcodebuild build -project "ResumeBuilder IOS APP.xcodeproj" -scheme "ResumeBuilder IOS APP" -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/rb-ios-dd CODE_SIGNING_ALLOWED=NO
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Simulator smoke of the actual regression**

The unit tests prove the invariant; this proves the user-visible symptom is gone.

1. Boot iPhone 17 (iOS 26.5), install the Debug build, complete one optimization so the Optimized tab shows a resume.
2. Kill the app. Turn off the simulator host's network (or point `Secrets.xcconfig`'s API base at an unroutable host to force `NSURLErrorCannotConnectToHost`).
3. Cold-launch the app and open the Optimized tab.
4. **Expected after fix:** the resume preview still renders (served from the cached `optimization_id`), and the tab does **not** show the `LockedTabTeaser` "Here's what you'll unlock" empty state. Before the fix it showed the teaser.
5. Restore the network, relaunch, confirm the tab still shows the resume.

Per `tasks/lessons.md:149`, `optimized_viewed` / `export_cta_seen` only fire once the Optimized tab is actually selected — select it explicitly. Per `tasks/lessons.md:63`, wait ~10s before trusting a screenshot.

- [ ] **Step 4: Record the lesson**

Append to `tasks/lessons.md`:

```markdown
## Never clear persisted state speculatively before a network call

**Rule:** Do not null a persisted identifier before the fetch that is meant to validate it.
`AppState.latestOptimizationId`'s setter writes through to `UserDefaults`, so clearing it
ahead of the history fetch made every transient `NSURLErrorCannotConnectToHost` permanently
destroy the user's completed optimization — the Optimized tab then rendered `LockedTabTeaser`
as if they had never optimized. Validate first, then mutate; and only clear on an
authoritative answer, never on a failure or an unrecognized status.

**Why:** `optimization_state_recovery_failed` fired for 9 of the 12 users who completed an
optimization and never reached the export CTA (2026-07-23 PostHog read). The event had been
live since 1.4.2 and was read as "recovery is flaky" rather than "recovery is destructive".
```

- [ ] **Step 5: Update progress and commit**

Update `tasks/progress.md` with Status, Current Phase, Active Story (WP-53), Last Completed Story, Next Recommended Story, Blockers, Last Validation, Last Updated: 2026-07-23.

```bash
git add tasks/lessons.md tasks/progress.md tasks/session-log.md
git commit -m "docs(tasks): record WP-53 optimization-id preservation lesson and progress"
```

- [ ] **Step 6: Push and open a PR**

```bash
git push -u origin HEAD && gh pr create --title "fix(ios): stop destroying the user's optimization id on recovery failure (WP-53)" --body "$(cat <<'EOF'
## Summary
A transient optimization-history fetch failure permanently destroyed `latestOptimizationId`, orphaning the user's completed optimization and locking them out of the preview and export path.

`reconcileLatestOptimization()` cleared the id *before* its network call, and the property's setter writes through to `UserDefaults`, so the clear survived relaunch. The catch block never restored it. This runs on every cold launch.

## Changes
- `AppState.reconcileLatestOptimization()` no longer clears the id speculatively, and restores it explicitly on the failure path.
- The authoritative-empty branch keeps a valid local id instead of discarding it when the server returns no status the client recognizes.
- A backend apply-rejection now throws instead of returning normally, so the caller stops treating a rejected apply as success. Analytics values (`backend_rejected` / `backend_error`) are unchanged and still emit exactly once.

## Not in scope
The `server_503` responses behind `optimization_apply_failed` originate in the web/backend repo (`OptimizationReviewView` already special-cases a 503 mentioning `operation_type`, suggesting a pending migration). Filed separately.

## Validation
- Red state observed for every test before implementing.
- Full suite: 214 tests / 1 intentional skip / 0 failures on iPhone 17 iOS 26.5.
- Release build: ** BUILD SUCCEEDED **.
- Simulator smoke: with the API host unroutable, a cold launch keeps rendering the resume instead of falling back to the locked-tab teaser.

## Not verified live
Whether this moves `optimized_preview_rendered` → `export_success` for real users needs a shipped build and a 14-day read.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## Post-ship verification (after the build is live, not part of implementation)

Run against PostHog project **270848** (switch explicitly and re-fingerprint first — the MCP banner can disagree with stored state):

```sql
SELECT
    properties.app_version AS ver,
    uniqIf(person_id, event = 'optimization_completed')      AS completed,
    uniqIf(person_id, event = 'optimized_preview_rendered')  AS preview,
    uniqIf(person_id, event = 'export_cta_seen')             AS cta,
    uniqIf(person_id, event = 'export_success')              AS activated,
    uniqIf(person_id, event = 'optimization_state_recovery_failed') AS recovery_failed
FROM events
WHERE timestamp >= now() - INTERVAL 14 DAY
  AND properties.$lib = 'resumely-ios-urlsession'
  AND person_id != 'a6441489-66c4-512d-9cf4-22b07652570e'
GROUP BY ver
ORDER BY ver DESC
```

**Success signal:** on the new build, `recovery_failed` may stay non-zero (the network still fails), but users who hit it should still appear in `preview`. The funnel must be monotonic: `completed >= preview >= cta >= activated`.

**Honest expectation:** at ~2.2 clean organic users/day, a 14-day read yields roughly 30 users. That is enough to see whether the recovery-failure cohort now reaches the preview, and **not** enough to certify an activation *rate*. Do not compute a percentage off it. EXD-022's ≥20 clean activations remains gated on distribution volume, which this fix does not address.
