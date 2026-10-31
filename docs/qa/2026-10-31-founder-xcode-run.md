# Founder Xcode run: prove the 10 StoreKit tests ran, 2026-10-31

**Do not run this on an iOS 26.5 simulator. It cannot pass there.**

I ran the `StoreKit Tests` scheme through the Xcode app on iPhone 17 Pro, iOS 26.5, on 31 Oct. Result: 10 failed, 0 passed, 0 skipped. The simulator's StoreKit service refused it and logged "is not installed for development".

The earlier plan said "one run from Xcode clears the skips". That was never tried, and it is wrong for this simulator.

Reports on Apple's forums (threads 826364 and 826971, read through a search summary) say the bug is in the iOS 26.5 simulator runtime, is a known issue with no workaround on that runtime, and does not affect real devices or iOS 26.0 to 26.2 simulators. Only iOS 26.5 is installed on this Mac.

Nothing here charges money or touches App Store Connect. The tests use a local file.

## Pick one

**Option A, recommended: a real iPhone.** No download. iPhone (77), an iPhone 13 Pro on iOS 18.7.8, showed as paired and available on 31 Oct. I did not run on it: the brief keeps me on the simulator. I have not seen this pass on a device, so this is my best guess, not a proven result.

**Option B: an older simulator.** Xcode, Settings, Components, then "+" and add iOS 26.2. This is a large download. Choose an iPhone with iOS 26.2 in step 5.

## Steps

1. Close any other Xcode window showing a Resumely project.
2. Connect and unlock the iPhone. Skip this for option B.
3. In Terminal, open this project:

```bash
open "/Users/nadavyigal/Developer/resumebuilder-worktrees/ios-pricing-v2/ResumeBuilder IOS APP.xcodeproj"
```

4. Wait until the top of the Xcode window stops saying "Indexing" or "Loading". Click the scheme name in the top bar, in the middle. Choose **StoreKit Tests**.
5. Click the device name next to it. Choose the **iPhone** (option A), or an **iOS 26.2** simulator (option B). Do not choose an iOS 26.5 simulator.
6. On a real iPhone only: if Xcode asks to fix signing, choose your team, 8VC4R5M425.
7. In the menu bar click **Product**, then **Test**. Or press Cmd+U.
8. On a real iPhone, if a "Developer Mode" or "Untrusted Developer" message shows, accept it on the phone and press Cmd+U again.
9. Wait. A first build can take 10 minutes or more.
10. Press **Cmd+9** to open the Report navigator. Click the top **Test** row.

## What proves it passed

All of these must be true:

- The report says **10 passed**, **0 failed**, **0 skipped**.
- The scheme is **StoreKit Tests** and the plan is **StoreKitRequired**.
- The device is not an iOS 26.5 simulator.
- These 10 rows are green under `StoreKitSessionTests`:
  - `testLoadsTwoPacksThenProAndNoRetiredPack`
  - `testBuyingProSendsItAndFinishesOnlyAfterTheGrant`
  - `testProOfAnotherAccountIsNotFinishedAndDoesNotLock`
  - `testAPackIsStillAConsumableGrant`
  - `testRefreshSendsTheCurrentPlanOnly`
  - `testARenewalIsSentAsTheCurrentPlan`
  - `testAnExpiredPlanIsNotSent`
  - `testARefundedPlanIsNotSent`
  - `testRestoreOnAnotherAccountNamesTheOwner`
  - `testGuestsSendNothing`

This plan cannot pass by skipping. With `REQUIRE_STOREKIT_TESTS=1` a file that did not load is a failure.

Take one screenshot of the report and send it to me. Then paste the output of this:

```bash
xcrun xcresulttool get test-results summary --path "$(ls -td ~/Library/Developer/Xcode/DerivedData/ResumeBuilder_IOS_APP-*/Logs/Test/*StoreKit*.xcresult | head -1)" | grep -E '"(result|totalTestCount|passedTests|failedTests|skippedTests|osVersion|deviceName)"'
```

Good output has `"result" : "Passed"`, `"totalTestCount" : 10`, `"passedTests" : 10`, `"failedTests" : 0` and `"skippedTests" : 0`.

## If it does not pass

| You see | It means | Do this |
|---|---|---|
| 10 failures, `StoreKitProductsNotLoaded` | The local file did not load | Check step 5. If it was a phone or iOS 26.2, send me the screenshot. |
| One or two failures with another message | A real bug, or a slow Mac | Send the failing name and message. |
| A pop-up asking to buy something | The wrong scheme ran | Cancel it. Repeat step 4. |
| Scheme "StoreKit Tests" is missing | Old checkout | Check step 3 used this exact folder. |
| Signing error on the phone | Device or team not set up | Send me the error. Use option B meanwhile. |

Cmd+U on the normal "ResumeBuilder IOS APP" scheme does not count. That scheme is allowed to skip.

Opening the project in Xcode rewrites `Resources/Localizable.xcstrings`: metadata and order only, no translations. It did this in my run. Do not commit that change. Discard it after the run:

```bash
git -C "/Users/nadavyigal/Developer/resumebuilder-worktrees/ios-pricing-v2" checkout -- "ResumeBuilder IOS APP/Resources/Localizable.xcstrings"
```

If neither option passes, the 10 cases stay unproven. The Sandbox matrix then carries that risk on a real phone: rows 3, 5, 6, 7, 8 and 9 cover the same paths with Apple's real Sandbox.
