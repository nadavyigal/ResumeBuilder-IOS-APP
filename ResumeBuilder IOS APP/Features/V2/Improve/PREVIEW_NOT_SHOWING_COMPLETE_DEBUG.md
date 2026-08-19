# 🔍 COMPLETE DEBUG: Preview Not Showing - WITH LOGGING

**Date**: May 15, 2026  
**Status**: 🔴 **ENHANCED DIAGNOSTICS ADDED**

---

## ✅ What I Just Did

I've added **comprehensive debug logging** throughout the optimization and preview flow. Now you can see **exactly** what's happening at each step.

### Files Modified with Debug Logging:

1. **`ImproveView.swift`** - Logs when optimize button is tapped
2. **`OptimizedResumeView.swift`** - Logs when view appears and sections load
3. **`ResumePreviewWebView.swift`** - Logs entire preview rendering process

---

## 🚀 What You Need to Do NOW

### Step 1: Ensure Mock Services Are Enabled

Open `BackendConfig.swift` line 7:

```swift
static let useMockServices = true  // ← MUST BE TRUE
```

### Step 2: Clean Build

```
Cmd+Shift+K
Delete app from simulator
Cmd+R
```

### Step 3: Open Console

**Before testing, open Xcode Console:**
```
Cmd+Shift+Y
```

Clear the console (trash icon).

### Step 4: Test the Flow

1. Upload a resume
2. Enter job description
3. Tap "Optimize for This Job"
4. **Watch the console carefully**

---

## 📊 What You Should See in Console

### Stage 1: Optimize Button Tapped

```
🚀 [IMPROVE VIEW] Optimize button tapped
```

### Stage 2: Optimization Complete

```
✅ [IMPROVE VIEW] Got optimization result
🔍 [IMPROVE VIEW] OptimizationId: mock-opt-001
🔍 [IMPROVE VIEW] ReviewId: nil
🔍 [IMPROVE VIEW] Sections count: 3
➡️ [IMPROVE VIEW] Navigating to optimized resume
✅ [IMPROVE VIEW] Navigation triggered
```

### Stage 3: Optimized View Appears

```
🔍 [OPTIMIZED VIEW] ========== VIEW APPEARED ==========
🔍 [OPTIMIZED VIEW] OptimizationId: mock-opt-001
🔍 [OPTIMIZED VIEW] Sections count: 3
🔍 [OPTIMIZED VIEW] Is loading: false
🔍 [OPTIMIZED VIEW] Using mock services: true
```

### Stage 4: Preview Rendering

```
🎨 [PREVIEW DEBUG] ========== RENDER PREVIEW STARTED ==========
🎨 [PREVIEW DEBUG] optimizationId: mock-opt-001
🎨 [PREVIEW DEBUG] templateId: nil
🎨 [PREVIEW DEBUG] sections count: 3
🎨 [PREVIEW DEBUG] customization: nil
🎨 [PREVIEW DEBUG] Using mock services: true
✅ [PREVIEW DEBUG] Token available, proceeding with render
📤 [PREVIEW DEBUG] Using templateId: ats-clean
📤 [PREVIEW DEBUG] Calling designService.renderPreview()
📥 [PREVIEW DEBUG] Got response from designService
📥 [PREVIEW DEBUG] Has HTML: true
📥 [PREVIEW DEBUG] HTML length: 2847
✅ [PREVIEW DEBUG] HTML successfully set, length: 2847
🎨 [PREVIEW DEBUG] ========== RENDER PREVIEW SUCCESS ==========
```

---

## ❌ Common Error Patterns

### Error Pattern 1: Mock Services Not Enabled

```
🎨 [PREVIEW DEBUG] Using mock services: false
📤 [PREVIEW DEBUG] Calling designService.renderPreview()
❌ [PREVIEW DEBUG] Exception caught: Network error
```

**Solution**: Set `BackendConfig.useMockServices = true`

### Error Pattern 2: No Token

```
🎨 [PREVIEW DEBUG] ========== RENDER PREVIEW STARTED ==========
❌ [PREVIEW DEBUG] No access token available
```

**Solution**: Sign in to the app first

### Error Pattern 3: Sections Empty

```
🔍 [OPTIMIZED VIEW] Sections count: 0
```

**Solution**: 
- Check if optimize returned sections
- Verify mock service is being used
- Check for errors in optimize step

### Error Pattern 4: Navigation Not Triggered

```
🚀 [IMPROVE VIEW] Optimize button tapped
❌ [IMPROVE VIEW] Optimization returned nil
```

**Solution**:
- Check for error message in UI
- Verify token exists
- Verify resumeId and jobDescriptionId exist

### Error Pattern 5: HTML Not Rendered

```
📥 [PREVIEW DEBUG] Has HTML: true
📥 [PREVIEW DEBUG] HTML length: 2847
✅ [PREVIEW DEBUG] HTML successfully set
[But nothing appears in UI]
```

**Solution**:
- WebView might have layout issues
- Check for errors in WebKit
- Verify aspectRatio constraint isn't causing issues

---

## 🔬 Diagnostic Checklist

Run through the flow and check off each stage:

### Before Optimize
- [ ] Console shows: "Using mock services: true" (in BackendConfig)
- [ ] Signed in to app
- [ ] Resume uploaded
- [ ] Job description entered

### During Optimize
- [ ] Console shows: "🚀 [IMPROVE VIEW] Optimize button tapped"
- [ ] Console shows: "✅ [IMPROVE VIEW] Got optimization result"
- [ ] Console shows: "Sections count: 3" (not 0)
- [ ] Console shows: "➡️ [IMPROVE VIEW] Navigating to optimized resume"

### Optimized View Load
- [ ] Console shows: "🔍 [OPTIMIZED VIEW] ========== VIEW APPEARED =========="
- [ ] Console shows: "OptimizationId: mock-opt-001" (not nil)
- [ ] Console shows: "Sections count: 3" (not 0)
- [ ] Console shows: "Using mock services: true"

### Preview Rendering
- [ ] Console shows: "🎨 [PREVIEW DEBUG] ========== RENDER PREVIEW STARTED =========="
- [ ] Console shows: "Using mock services: true"
- [ ] Console shows: "✅ [PREVIEW DEBUG] Token available"
- [ ] Console shows: "📤 [PREVIEW DEBUG] Calling designService.renderPreview()"
- [ ] Console shows: "📥 [PREVIEW DEBUG] Has HTML: true"
- [ ] Console shows: "HTML length: 2847" (not 0)
- [ ] Console shows: "✅ [PREVIEW DEBUG] HTML successfully set"
- [ ] Console shows: "🎨 [PREVIEW DEBUG] ========== RENDER PREVIEW SUCCESS =========="

### Visual Confirmation
- [ ] Screen shows "Optimized Resume" title
- [ ] Screen shows preview content (not blank)
- [ ] Screen shows bottom bar with buttons
- [ ] Can see resume text in preview

---

## 🎯 What Each Stage Means

### Stage 1: Optimize Request
- **What happens**: App calls mock service to optimize resume
- **Expected**: Returns 3 sections after 2 second delay
- **Check**: If this fails, optimization itself is broken

### Stage 2: Navigation
- **What happens**: App navigates to OptimizedResumeView
- **Expected**: View appears with sections already loaded
- **Check**: If sections are empty here, navigation data wasn't passed correctly

### Stage 3: View Setup
- **What happens**: View loads, checks if sections need fetching
- **Expected**: Sections already present (count: 3), no fetch needed
- **Check**: If loading happens here, sections weren't passed in init

### Stage 4: Preview Render
- **What happens**: WebView requests HTML from mock service
- **Expected**: Mock returns styled HTML string
- **Check**: If HTML is empty, mock service render is broken

### Stage 5: WebView Display
- **What happens**: WKWebView renders HTML
- **Expected**: Resume appears in preview frame
- **Check**: If blank, WebView has layout or rendering issue

---

## 🛠️ Troubleshooting by Stage

### If Stage 1 Fails (Optimize)

**Console shows**:
```
🚀 [IMPROVE VIEW] Optimize button tapped
❌ [IMPROVE VIEW] Optimization returned nil
```

**Check**:
1. Is there an error message in the UI?
2. Do you see any exceptions in console?
3. Is `BackendConfig.useMockServices = true`?

**Debug**:
- Check ImproveViewModel.optimize() is being called
- Verify token exists
- Check mock service is configured

### If Stage 2 Fails (Navigation)

**Console shows**:
```
✅ [IMPROVE VIEW] Navigation triggered
[But OptimizedResumeView never appears]
```

**Check**:
1. Is `navigateToOptimized` being set to true?
2. Is `navigationDestination` modifier present?
3. Are you in a NavigationStack?

**Debug**:
- Verify ImproveView has NavigationStack wrapper
- Check if another navigation is blocking this one

### If Stage 3 Fails (View Setup)

**Console shows**:
```
🔍 [OPTIMIZED VIEW] ========== VIEW APPEARED ==========
🔍 [OPTIMIZED VIEW] OptimizationId: nil
```

**OR**:
```
🔍 [OPTIMIZED VIEW] Sections count: 0
```

**Check**:
1. Was optimizationId nil in Stage 2?
2. Were sections empty in Stage 2?
3. Is data being passed to OptimizedResumeViewModel init?

**Debug**:
- Check ImproveView lines where OptimizedResumeViewModel is created
- Verify `currentOptId` and `optimizedSections` are set

### If Stage 4 Fails (Preview Render)

**Console shows**:
```
📥 [PREVIEW DEBUG] Has HTML: false
```

**OR**:
```
📥 [PREVIEW DEBUG] HTML length: 0
```

**Check**:
1. Is mock service actually being used?
2. Is renderPreview() in mock returning HTML?
3. Any exceptions thrown?

**Debug**:
- Check MockResumeDesignService.renderPreview() exists
- Verify it returns RenderPreviewResponse with HTML
- Check if there's a Swift error being swallowed

### If Stage 5 Fails (WebView Display)

**Console shows**:
```
✅ [PREVIEW DEBUG] HTML successfully set, length: 2847
🎨 [PREVIEW DEBUG] ========== RENDER PREVIEW SUCCESS ==========
[But screen is blank]
```

**Check**:
1. Is WebView actually in the view hierarchy?
2. Is it sized properly?
3. Any WebKit errors?

**Debug**:
- Check OptimizedResumeView's body for ResumePreviewWebView
- Verify `let optId = viewModel.optimizationIdentifier` is not nil
- Check `.aspectRatio(8.5 / 11)` isn't causing zero-size frame

---

## 🎯 Most Likely Issues (Ranked)

### Issue #1: Mock Services Not Enabled (90% likely)

**Symptom**: Network errors, empty responses

**Fix**: `BackendConfig.useMockServices = true`

### Issue #2: Not Signed In (5% likely)

**Symptom**: "Sign in to preview" message

**Fix**: Sign in before optimizing

### Issue #3: Navigation State Issues (3% likely)

**Symptom**: Optimize completes but nothing happens

**Fix**: Check NavigationStack is present in ImproveView

### Issue #4: WebView Layout Issues (2% likely)

**Symptom**: HTML set but nothing visible

**Fix**: Check frame size, remove aspectRatio temporarily

---

## ✅ Success Criteria

### Console Output (Complete Flow)

```
🚀 [IMPROVE VIEW] Optimize button tapped
✅ [IMPROVE VIEW] Got optimization result
🔍 [IMPROVE VIEW] OptimizationId: mock-opt-001
🔍 [IMPROVE VIEW] Sections count: 3
➡️ [IMPROVE VIEW] Navigating to optimized resume
✅ [IMPROVE VIEW] Navigation triggered

🔍 [OPTIMIZED VIEW] ========== VIEW APPEARED ==========
🔍 [OPTIMIZED VIEW] OptimizationId: mock-opt-001
🔍 [OPTIMIZED VIEW] Sections count: 3
🔍 [OPTIMIZED VIEW] Using mock services: true
✅ [OPTIMIZED VIEW] DesignViewModel created
🔍 [OPTIMIZED VIEW] ========== VIEW SETUP COMPLETE ==========

🎨 [PREVIEW DEBUG] ========== RENDER PREVIEW STARTED ==========
🎨 [PREVIEW DEBUG] optimizationId: mock-opt-001
🎨 [PREVIEW DEBUG] sections count: 3
🎨 [PREVIEW DEBUG] Using mock services: true
✅ [PREVIEW DEBUG] Token available, proceeding with render
📤 [PREVIEW DEBUG] Using templateId: ats-clean
📤 [PREVIEW DEBUG] Calling designService.renderPreview()
📥 [PREVIEW DEBUG] Got response from designService
📥 [PREVIEW DEBUG] Has HTML: true
📥 [PREVIEW DEBUG] HTML length: 2847
✅ [PREVIEW DEBUG] HTML successfully set, length: 2847
🎨 [PREVIEW DEBUG] ========== RENDER PREVIEW SUCCESS ==========
```

### Visual Result

You should see a screen like this:

```
┌─────────────────────────────────────┐
│  Optimized Resume           ⋯       │
├─────────────────────────────────────┤
│                                     │
│  ┌────────────────────────────┐    │
│  │ Your Name                  │    │
│  │ email@example.com          │    │
│  │                            │    │
│  │ PROFESSIONAL SUMMARY       │    │
│  │ Results-driven software    │    │
│  │ engineer with 5+ years...  │    │
│  │                            │    │
│  │ EXPERIENCE                 │    │
│  │ Senior Engineer @ TechCorp │    │
│  │ Led migration of monolith  │    │
│  │ to microservices...        │    │
│  │                            │    │
│  │ SKILLS                     │    │
│  │ TypeScript, React, Node.js │    │
│  │ Kubernetes, Docker, AWS    │    │
│  └────────────────────────────┘    │
│                                     │
│  [Refine Resume]                    │
│                                     │
│  [Send to Expert]  [Open Design]    │
└─────────────────────────────────────┘
```

---

## 💬 Report Template

After testing with the new logging, tell me:

### 1. Mock Services Status
- [ ] `BackendConfig.useMockServices = true` ✅
- [ ] `BackendConfig.useMockServices = false` ❌

### 2. Console Output

**Stage 1 (Optimize):**
```
[Paste console output starting with 🚀 [IMPROVE VIEW]]
```

**Stage 2 (View Load):**
```
[Paste console output starting with 🔍 [OPTIMIZED VIEW]]
```

**Stage 3 (Preview):**
```
[Paste console output starting with 🎨 [PREVIEW DEBUG]]
```

### 3. What Do You See?

- [ ] Blank screen
- [ ] Loading spinner forever
- [ ] Error message: _________________
- [ ] Preview appears! (Success!)
- [ ] Something else: _________________

### 4. Screenshots

If possible, share:
- Screenshot of the screen
- Screenshot of console output

---

## 🔧 Quick Actions

### Action 1: Force Mocks (Immediate)

```swift
// BackendConfig.swift line 7
static let useMockServices = true
```

### Action 2: Clean Build (Always)

```
Cmd+Shift+K
Delete app
Cmd+R
```

### Action 3: Test & Report (Critical)

1. Open console
2. Clear console
3. Test optimize flow
4. Copy ALL console output
5. Paste here

---

**Status**: 🟢 **DIAGNOSTICS READY - TEST NOW**

The enhanced logging will tell us **exactly** where the flow is breaking. Test it now and share the console output!

