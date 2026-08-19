# 🔴 CRITICAL FIXES NEEDED: Preview Still Not Showing + Saved Resumes Not Working

**Status**: Two major issues remain after recent fixes

---

## 🎯 Issue #1: Preview Still Not Showing

### What Was Fixed
✅ `ResumeDesignService.swift` - Added JSON/HTML fallback parsing  
✅ `ResumeOptimizationService.swift` - Fixed `review_id` snake_case decoding  
✅ `DomainModels.swift` - Added CodingKeys for `OptimizationDetailDTO`

### What's Still Broken
❌ The `renderPreview` implementation is **OUTDATED** in the file you showed me

---

## 🔧 Fix #1: Update ResumeDesignService.swift with Correct Implementation

The version I see in the codebase (lines 55-80) is treating the response as **raw HTML only**. But you mentioned it should try JSON first, then fall back to HTML.

### Current Code (WRONG):
```swift
func renderPreview(_ request: RenderPreviewRequest, token: String) async throws -> RenderPreviewResponse {
    // ... setup request ...
    let (responseData, response) = try await URLSession.shared.data(for: urlRequest)
    guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
        throw APIClientError.invalidResponse
    }
    let html = String(data: responseData, encoding: .utf8) ?? ""
    return RenderPreviewResponse(success: true, previewHTML: html, error: nil)
}
```

**Problem**: This **always** treats response as raw HTML, even if backend returns JSON.

### Correct Code (FIX):
```swift
func renderPreview(_ request: RenderPreviewRequest, token: String) async throws -> RenderPreviewResponse {
    let encoder = JSONEncoder()
    guard let data = try? encoder.encode(request),
          let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        throw APIClientError.invalidResponse
    }
    
    var components = URLComponents(url: BackendConfig.apiBaseURL, resolvingAgainstBaseURL: false)!
    components.path = Endpoint.designRenderPreview.path
    guard let url = components.url else { throw APIClientError.invalidResponse }
    
    var urlRequest = URLRequest(url: url, timeoutInterval: 60)
    urlRequest.httpMethod = "POST"
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
    
    let (responseData, response) = try await URLSession.shared.data(for: urlRequest)
    
    guard let http = response as? HTTPURLResponse else {
        throw APIClientError.invalidResponse
    }
    
    // Add debug logging
    print("📥 [RenderPreview] status=\(http.statusCode)")
    print("📥 [RenderPreview] content-type=\(http.value(forHTTPHeaderField: "Content-Type") ?? "unknown")")
    print("📥 [RenderPreview] body preview=\(String(data: responseData.prefix(200), encoding: .utf8) ?? "binary")...")
    
    // Check status code
    guard (200...299).contains(http.statusCode) else {
        // Try to extract error message from response
        if let errorBody = String(data: responseData, encoding: .utf8) {
            if let jsonError = try? JSONDecoder().decode(RenderPreviewResponse.self, from: responseData) {
                return jsonError // Return the error from JSON
            }
            throw APIClientError.serverError(status: http.statusCode, message: errorBody)
        }
        throw APIClientError.serverError(status: http.statusCode, message: "Preview generation failed")
    }
    
    // Try to decode as JSON first
    if let jsonResponse = try? JSONDecoder().decode(RenderPreviewResponse.self, from: responseData) {
        print("✅ [RenderPreview] Decoded as JSON")
        return jsonResponse
    }
    
    // Fall back to treating entire body as raw HTML
    let html = String(data: responseData, encoding: .utf8) ?? ""
    print("✅ [RenderPreview] Treating as raw HTML, length: \(html.count)")
    return RenderPreviewResponse(success: true, previewHTML: html, error: nil)
}
```

**Key Changes**:
1. ✅ Added debug logging for status, content-type, and body preview
2. ✅ Tries JSON decoding FIRST
3. ✅ Falls back to raw HTML if JSON fails
4. ✅ Extracts actual error message from server responses
5. ✅ Throws proper `serverError` with status code and message

---

## 🎯 Issue #2: Saved Resumes Not Working

### Current Problem
Looking at `BackendConfig.swift`:
```swift
static let useMockLibraryService = true  // ← Still using MOCKS for library
```

This means saved resumes are using **mock data**, not real backend!

### Fix: Enable Real Library Service

**File: `BackendConfig.swift` line 9**

```swift
// BEFORE:
static let useMockLibraryService = true

// AFTER:
static let useMockLibraryService = false  // ← Use real backend for library
```

### But Wait - Backend Endpoints Must Exist!

The real backend needs these endpoints:

1. **GET `/api/v1/resumes`** - List saved resumes
   ```json
   {
     "resumes": [
       {
         "id": "uuid",
         "filename": "resume.pdf",
         "display_name": "My Resume",
         "size_bytes": 45678,
         "created_at": "2026-05-15T10:00:00Z"
       }
     ]
   }
   ```

2. **POST `/api/v1/resumes/{id}/save`** - Save a resume
   ```json
   {
     "id": "uuid",
     "display_name": "Software Engineer Resume"
   }
   ```

3. **DELETE `/api/v1/resumes/{id}`** - Delete a resume

4. **PUT `/api/v1/resumes/{id}/rename`** - Rename a resume
   ```json
   {
     "display_name": "New Name"
   }
   ```

5. **GET `/api/v1/resumes/{id}/download`** - Download PDF

**According to your prompt**, these endpoints might not exist yet (hence the note "Flip to `false` once `/api/v1/resumes` endpoints ship").

---

## 🚨 Critical Next Steps (In Order)

### Step 1: Apply ResumeDesignService Fix

1. Open `ResumeDesignService.swift`
2. Replace the `renderPreview` function with the corrected version above
3. Save the file

### Step 2: Add More Debug Logging to Preview Flow

In `ResumePreviewWebView.swift`, the `renderPreview` function already has logging, but add this at the end:

```swift
private func renderPreview() async {
    print("🎨 [PREVIEW DEBUG] ========== RENDER PREVIEW STARTED ==========")
    print("🎨 [PREVIEW DEBUG] optimizationId: \(optimizationId)")
    print("🎨 [PREVIEW DEBUG] templateId: \(templateId ?? "nil")")
    print("🎨 [PREVIEW DEBUG] sections count: \(sections.count)")
    print("🎨 [PREVIEW DEBUG] customization: \(String(describing: customization))")
    print("🎨 [PREVIEW DEBUG] Using mock services: \(BackendConfig.useMockServices)")
    
    guard let token = appState.session?.accessToken else {
        print("❌ [PREVIEW DEBUG] No access token available")
        errorMessage = "Sign in to preview your resume."
        isLoading = false
        return
    }
    
    print("✅ [PREVIEW DEBUG] Token available, proceeding with render")
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }
    do {
        let effectiveTemplateId = templateId ?? "ats-clean"
        print("📤 [PREVIEW DEBUG] Using templateId: \(effectiveTemplateId)")
        
        let request = RenderPreviewRequest(
            optimizationId: optimizationId,
            templateId: effectiveTemplateId,
            customization: customization ?? .default,
            resumeData: nil
        )
        
        print("📤 [PREVIEW DEBUG] Calling designService.renderPreview()")
        let response = try await designService.renderPreview(request, token: token)
        
        print("📥 [PREVIEW DEBUG] Got response from designService")
        print("📥 [PREVIEW DEBUG] Success: \(response.success ?? false)")
        print("📥 [PREVIEW DEBUG] Has HTML: \(response.previewHTML != nil)")
        print("📥 [PREVIEW DEBUG] HTML length: \(response.previewHTML?.count ?? 0)")
        print("📥 [PREVIEW DEBUG] Error: \(response.error ?? "none")")
        
        if let previewHTML = response.previewHTML, !previewHTML.isEmpty {
            html = previewHTML
            print("✅ [PREVIEW DEBUG] HTML successfully set, length: \(previewHTML.count)")
            print("✅ [PREVIEW DEBUG] First 200 chars: \(previewHTML.prefix(200))")
            print("🎨 [PREVIEW DEBUG] ========== RENDER PREVIEW SUCCESS ==========")
        } else {
            errorMessage = response.error ?? "Preview unavailable. The server returned no HTML."
            print("❌ [PREVIEW DEBUG] No HTML in response")
            print("🎨 [PREVIEW DEBUG] ========== RENDER PREVIEW FAILED ==========")
        }
    } catch let error as APIClientError {
        switch error {
        case .serverError(let status, let message):
            errorMessage = "Server error (\(status)): \(message)"
            print("❌ [PREVIEW DEBUG] Server error \(status): \(message)")
        case .invalidResponse:
            errorMessage = "Invalid response from server"
            print("❌ [PREVIEW DEBUG] Invalid response")
        case .unauthorized:
            errorMessage = "Authentication failed"
            print("❌ [PREVIEW DEBUG] Unauthorized")
        case .paymentRequired:
            errorMessage = "Upgrade required"
            print("❌ [PREVIEW DEBUG] Payment required")
        }
        print("🎨 [PREVIEW DEBUG] ========== RENDER PREVIEW ERROR ==========")
    } catch {
        errorMessage = "Preview failed: \(error.localizedDescription)"
        print("❌ [PREVIEW DEBUG] Unexpected error: \(error)")
        print("❌ [PREVIEW DEBUG] Error type: \(type(of: error))")
        print("🎨 [PREVIEW DEBUG] ========== RENDER PREVIEW ERROR ==========")
    }
}
```

### Step 3: Clean Build and Test

```
1. Cmd+Shift+K (Clean)
2. Delete app from simulator
3. Cmd+R (Run)
```

### Step 4: Test Optimize Flow and Check Console

1. Open Xcode Console (Cmd+Shift+Y)
2. Clear console
3. Upload resume + enter job description
4. Tap "Optimize for This Job"
5. **Watch console output carefully**

### Step 5: Analyze Console Output

Look for the new `[RenderPreview]` logs:

**Good Output:**
```
📤 [PREVIEW DEBUG] Calling designService.renderPreview()
📥 [RenderPreview] status=200
📥 [RenderPreview] content-type=application/json
📥 [RenderPreview] body preview={"success":true,"preview_html":"<html>...
✅ [RenderPreview] Decoded as JSON
📥 [PREVIEW DEBUG] Has HTML: true
📥 [PREVIEW DEBUG] HTML length: 5234
✅ [PREVIEW DEBUG] HTML successfully set
```

**Bad Output (JSON Error):**
```
📥 [RenderPreview] status=400
📥 [RenderPreview] body preview={"error":"Template not assigned"}...
❌ [PREVIEW DEBUG] Server error 400: Template not assigned
```

**Bad Output (No Endpoint):**
```
📥 [RenderPreview] status=404
❌ [PREVIEW DEBUG] Server error 404: Not Found
```

**Bad Output (HTML Parsing Issue):**
```
📥 [RenderPreview] status=200
📥 [RenderPreview] content-type=text/html
✅ [RenderPreview] Treating as raw HTML, length: 4567
📥 [PREVIEW DEBUG] HTML length: 4567
✅ [PREVIEW DEBUG] HTML successfully set
[But nothing appears in UI]
```

---

## 🔍 Troubleshooting Based on Console Output

### Scenario 1: Status 404 (Endpoint Not Found)

**Console shows**:
```
📥 [RenderPreview] status=404
```

**Problem**: Backend doesn't have `/api/design/render-preview` endpoint

**Solution**: Implement the endpoint on backend or verify the path is correct

### Scenario 2: Status 400 (Bad Request)

**Console shows**:
```
📥 [RenderPreview] status=400
📥 [RenderPreview] body preview={"error":"optimization_id is required"}
```

**Problem**: Request format is wrong

**Solutions**:
- Check if request body has correct field names
- Verify CodingKeys in RenderPreviewRequest
- Check backend expects same field names

### Scenario 3: Status 401 (Unauthorized)

**Console shows**:
```
📥 [RenderPreview] status=401
```

**Problem**: Token is invalid or expired

**Solutions**:
- Check token is being sent in Authorization header
- Verify token isn't expired
- Try logging out and back in

### Scenario 4: Status 500 (Server Error)

**Console shows**:
```
📥 [RenderPreview] status=500
📥 [RenderPreview] body preview=<html>Internal Server Error...
```

**Problem**: Backend crashed

**Solutions**:
- Check backend logs for exception
- Fix the bug in backend code
- Check if database query is failing

### Scenario 5: Status 200 but No HTML

**Console shows**:
```
📥 [RenderPreview] status=200
✅ [RenderPreview] Decoded as JSON
📥 [PREVIEW DEBUG] Has HTML: false
📥 [PREVIEW DEBUG] HTML length: 0
```

**Problem**: Backend returns success but no HTML

**Solutions**:
- Check backend actually generates HTML
- Verify template exists in database
- Check if sections are being passed correctly

### Scenario 6: HTML Set but Nothing Renders

**Console shows**:
```
✅ [PREVIEW DEBUG] HTML successfully set, length: 5234
✅ [PREVIEW DEBUG] First 200 chars: <!DOCTYPE html><html><head>...
```

**Problem**: WebView isn't rendering

**Solutions**:
- Check WebView frame size (might be zero)
- Remove `.aspectRatio(8.5 / 11)` temporarily to test
- Check for JavaScript errors in HTML
- Try simpler HTML to isolate issue

---

## 📋 Saved Resume Issue - Separate Investigation

### Current Status
- `useMockLibraryService = true` - Using fake data
- Backend `/api/v1/resumes` endpoints don't exist yet (per your note)

### To Fix Saved Resumes

**Option 1: Implement Backend Endpoints (Recommended)**
1. Create `/api/v1/resumes` endpoint
2. Implement list/save/delete/rename/download
3. Set `useMockLibraryService = false`

**Option 2: Keep Using Mocks for Now**
- Leave `useMockLibraryService = true`
- Focus on fixing preview first
- Implement library endpoints later

---

## ✅ Complete Checklist

### Preview Fix
- [ ] Update `ResumeDesignService.swift` `renderPreview` function
- [ ] Add enhanced logging to `ResumePreviewWebView.swift`
- [ ] Clean build and run
- [ ] Test optimize flow
- [ ] Check console for `[RenderPreview]` logs
- [ ] Verify HTML is being received
- [ ] Verify WebView displays content

### Saved Resume Fix (Future)
- [ ] Implement backend `/api/v1/resumes` endpoints
- [ ] Set `useMockLibraryService = false`
- [ ] Test list/save/delete/rename/download
- [ ] Verify PDF download works

---

## 🎯 Expected Timeline

**Immediate (5 minutes)**:
- Apply ResumeDesignService fix
- Add logging
- Rebuild

**Short-term (15 minutes)**:
- Test optimize flow
- Analyze console output
- Identify exact issue

**Medium-term (1 hour)**:
- Fix backend endpoint if needed
- OR fix request format if mismatch
- Verify preview works end-to-end

**Long-term (later)**:
- Implement library endpoints
- Enable real saved resumes

---

## 💬 What to Report Back

After applying the fix and testing, tell me:

### 1. Console Output
```
[Paste the complete console output here, especially lines with:]
- 📥 [RenderPreview] status=...
- 📥 [RenderPreview] content-type=...
- 📥 [RenderPreview] body preview=...
- ✅ or ❌ [PREVIEW DEBUG] messages
```

### 2. Status Code
- [ ] 200 (Success)
- [ ] 400 (Bad Request)
- [ ] 401 (Unauthorized)
- [ ] 404 (Not Found)
- [ ] 500 (Server Error)
- [ ] Other: _____

### 3. Response Type
- [ ] JSON response
- [ ] Raw HTML response
- [ ] Error message
- [ ] Empty/No response

### 4. Visual Result
- [ ] Preview shows content ✅
- [ ] Preview is blank
- [ ] Error message displayed
- [ ] Loading spinner forever
- [ ] App crashes

---

**Priority**: Apply the `ResumeDesignService.swift` fix FIRST, then test and report console output!

