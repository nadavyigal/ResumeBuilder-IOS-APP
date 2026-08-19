# 🎯 CLAUDE CODE PROMPT: Complete Backend Configuration & Verify Preview/Design

**Copy and paste this into Claude Code:**

---

I need help completing the backend configuration and ensuring the preview and design features work correctly in my iOS resume builder app.

## 🔴 Current Issues

### Issue 1: Compile Errors in TailorViewModel.swift
Getting these errors:
- `error: Cannot assign to value: 'selectedResumeURL' is a 'let' constant`
- `error: 'nil' cannot be assigned to type 'URL'`

**Location**: Lines 80-81 in `optimize()` function

**Problem**: Trying to set `selectedResumeURL = nil` and `selectedResumeName = nil` but they're declared as non-optional or constants.

**Fix needed**: Make these properly optional and mutable, or remove the reset logic.

---

### Issue 2: Preview Still Not Showing (Real Backend)
- Using real backend (`BackendConfig.useMockServices = false`)
- Preview not rendering after optimization
- Need to verify all backend endpoints work

---

### Issue 3: Design Templates Not Loading (Real Backend)
- Design sheet may not be loading templates from real backend
- Need to verify template endpoints and data

---

### Issue 4: Saved Resumes Using Mocks
- `BackendConfig.useMockLibraryService = true` 
- Need to implement backend endpoints or document what's needed

---

## 🎯 Tasks to Complete

### Task 1: Fix TailorViewModel Compile Errors

**File**: `TailorViewModel.swift` around line 80

**Current code (BROKEN)**:
```swift
// Line 8-9: These are optional
var selectedResumeURL: URL?
var selectedResumeName: String?

// Line 80-81: But trying to assign nil fails
selectedResumeURL = nil
selectedResumeName = nil
```

**Expected fix**: These should already be optional (`URL?`), so the assignment should work. Check:
1. Are they actually declared as optional?
2. Is there a typo or extra code?
3. Are you in the right scope?

**Action**: Fix the syntax errors so the code compiles.

---

### Task 2: Add Comprehensive API Logging

Add logging to **all** API calls to see exactly what's happening:

#### In `APIClient.swift`:

Add logging in the main request functions (GET, POST, etc.):

```swift
func postJSON<T: Decodable>(
    endpoint: Endpoint,
    body: [String: Any],
    token: String
) async throws -> T {
    // Log request
    print("📤 [API] POST \(endpoint.path)")
    print("📤 [API] Headers: Authorization=Bearer \(token.prefix(20))...")
    if let bodyData = try? JSONSerialization.data(withJSONObject: body),
       let bodyString = String(data: bodyData, encoding: .utf8) {
        print("📤 [API] Body: \(bodyString)")
    }
    
    // Make request
    let data = try await ... // existing code
    
    // Log response
    print("📥 [API] Response status: \(httpResponse.statusCode)")
    if let responseString = String(data: data, encoding: .utf8) {
        print("📥 [API] Response body: \(responseString.prefix(500))...")
    }
    
    return decoded
}
```

Do the same for:
- `get(endpoint:token:)`
- `getWithQuery(endpoint:token:)`
- `uploadResume(fileURL:jobDescription:jobDescriptionURL:token:)`

---

### Task 3: Verify Backend Endpoints Exist

Test each critical endpoint with curl or similar:

#### Optimization Flow:

**1. Upload Resume**
```bash
curl -X POST "https://www.resumelybuilderai.com/api/upload" \
  -H "Authorization: Bearer $TOKEN" \
  -F "resume=@test-resume.pdf" \
  -F "job_description=Software Engineer position..."
```

**Expected response**:
```json
{
  "success": true,
  "resume_id": "uuid",
  "job_description_id": "uuid",
  "next_step": "optimize"
}
```

**2. Optimize Resume**
```bash
curl -X POST "https://www.resumelybuilderai.com/api/optimize" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "resume_id": "uuid",
    "job_description_id": "uuid"
  }'
```

**Expected response**:
```json
{
  "success": true,
  "optimization_id": "opt-uuid",
  "sections": [
    {
      "id": "s1",
      "type": "summary",
      "body": "Optimized text...",
      "status": "optimized"
    }
  ]
}
```

**3. Get Optimization Details**
```bash
curl -X GET "https://www.resumelybuilderai.com/api/optimization/{id}" \
  -H "Authorization: Bearer $TOKEN"
```

**Expected response**:
```json
{
  "optimization_id": "opt-uuid",
  "sections": [...],
  "job_title": "Software Engineer",
  "company": "Tech Corp",
  "ats_score_before": 65,
  "ats_score_after": 82
}
```

#### Design Flow:

**4. Get Templates**
```bash
curl -X GET "https://www.resumelybuilderai.com/api/design/templates?category=traditional" \
  -H "Authorization: Bearer $TOKEN"
```

**Expected response**:
```json
{
  "templates": [
    {
      "id": "tpl-1",
      "slug": "classic-ats",
      "name": "Classic ATS",
      "category": "traditional",
      "is_premium": false,
      "ats_score": 95
    }
  ]
}
```

**5. Assign Template**
```bash
curl -X POST "https://www.resumelybuilderai.com/api/design/assignment/{optimization_id}" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"template_id": "tpl-1"}'
```

**6. Render Preview**
```bash
curl -X POST "https://www.resumelybuilderai.com/api/design/render-preview" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "optimization_id": "opt-uuid",
    "template_id": "tpl-1",
    "customization": {
      "spacing": 0.5,
      "accent_color": "6366F1",
      "font_style": "modern"
    }
  }'
```

**Expected response** (Option A - JSON):
```json
{
  "success": true,
  "preview_html": "<!DOCTYPE html>..."
}
```

**Expected response** (Option B - Raw HTML):
```html
<!DOCTYPE html>
<html>
<head>...</head>
<body>...</body>
</html>
```

---

### Task 4: Document Missing Endpoints

For each endpoint that returns 404 or doesn't exist:

1. Document the expected request format
2. Document the expected response format
3. Note if it's critical for app functionality
4. Suggest whether to:
   - Keep using mocks for now
   - Implement endpoint
   - Use alternative approach

---

### Task 5: Test Complete Flow End-to-End

With logging enabled, test the full flow in the iOS app:

1. **Upload & Optimize**:
   - Upload a test resume
   - Enter job description
   - Tap "Optimize"
   - **Check console** for all API logs
   - Verify navigation to OptimizedResumeView

2. **Preview**:
   - After optimization succeeds
   - Check if ResumePreviewWebView appears
   - **Check console** for:
     - `📥 [RenderPreview] status=...`
     - `📥 [RenderPreview] body preview=...`
   - Verify HTML is received and rendered

3. **Design**:
   - Tap "Open Design" button
   - **Check console** for template loading
   - Verify templates appear in UI
   - Select a template
   - Tap "Apply Design"
   - Verify no errors

4. **Saved Resumes**:
   - Tap "Use a saved resume"
   - Verify list loads (mocks or real)
   - Select a resume
   - Verify file loads
   - Tap "Optimize"
   - Verify no permission errors

---

### Task 6: Fix Data Model Mismatches

If backend returns different field names than iOS expects:

**Check these DTOs in `DomainModels.swift`**:
- `ResumeUploadResponse` - Does it match backend?
- `OptimizeResponse` - reviewId vs review_id?
- `OptimizationDetailDTO` - CodingKeys for snake_case?
- `RenderPreviewResponse` - preview_html vs previewHTML?
- `DesignTemplate` - Field names match?

**Add CodingKeys where needed**:
```swift
struct MyDTO: Codable {
    let myField: String
    let anotherField: Int
    
    private enum CodingKeys: String, CodingKey {
        case myField = "my_field"           // Backend uses snake_case
        case anotherField = "another_field"
    }
}
```

---

### Task 7: Handle Backend Errors Gracefully

Ensure all error cases are handled:

**In services (e.g., ResumeOptimizationService.swift)**:
```swift
do {
    let response: OptimizeResponse = try await apiClient.postJSON(...)
    
    // Check for error field
    if let error = response.error, !error.isEmpty {
        throw APIClientError.serverError(status: 400, message: error)
    }
    
    // Check for missing required fields
    guard let optimizationId = response.optimizationId else {
        throw APIClientError.serverError(status: 500, message: "No optimization_id in response")
    }
    
    return response
} catch let error as APIClientError {
    // Log the specific error
    print("❌ [OPTIMIZATION] API Error: \(error)")
    throw error
} catch {
    print("❌ [OPTIMIZATION] Unexpected error: \(error)")
    throw error
}
```

---

### Task 8: Enable/Disable Mock Services Appropriately

Based on what endpoints exist, configure:

**In `BackendConfig.swift`**:

```swift
// Use mocks only for features not yet implemented on backend
static let useMockServices = false  // Main optimize/upload flow works
static let useMockLibraryService = true  // Library endpoints don't exist yet
```

Or create granular flags:

```swift
static let useMockOptimizationService = false  // Backend works
static let useMockDesignService = false        // Backend works
static let useMockLibraryService = true        // Backend missing
static let useMockAnalysisService = false      // Backend works
```

---

## 📊 Deliverables

After completing the tasks, provide:

### 1. Endpoint Status Report

For each endpoint, report:
- ✅ Exists and works
- ⚠️ Exists but has issues
- ❌ Doesn't exist
- 🔧 Needs fixes

Example:
```
POST /api/upload: ✅ Works
POST /api/optimize: ✅ Works
GET /api/optimization/{id}: ⚠️ Returns wrong field names
POST /api/design/render-preview: ❌ 404 Not Found
GET /api/design/templates: ✅ Works
GET /api/v1/resumes: ❌ Not implemented
```

### 2. API Logs

Paste the complete console output from a test run showing:
- All API requests
- All API responses
- Any errors
- Navigation flow

### 3. Data Model Fixes

List any DTOs that needed CodingKeys added or fields changed.

### 4. Configuration Recommendations

Suggest final BackendConfig settings:
```swift
static let useMockServices = ?  // true or false
static let useMockLibraryService = ?  // true or false
```

### 5. Missing Features List

Document what backend endpoints are missing and whether they're critical:
- Critical: App won't work without them
- Important: Core feature missing
- Nice to have: Can use mocks for now

### 6. Working Features List

Document what IS working:
- ✅ Upload resume
- ✅ Optimize resume
- ✅ View optimized result
- ✅ Preview rendering
- ✅ Design templates
- ❌ Saved resumes (mocked)

---

## 🎯 Success Criteria

The app should be able to:

1. ✅ Upload a PDF resume
2. ✅ Enter job description
3. ✅ Optimize resume
4. ✅ Navigate to OptimizedResumeView
5. ✅ Display optimized sections
6. ✅ Render HTML preview
7. ✅ Open design sheet
8. ✅ Load templates (by category)
9. ✅ Apply design customization
10. ✅ Download PDF

With clear console logs showing exactly what's happening at each step.

---

## 🔧 Priority Order

1. **P0 (Critical)**: Fix compile errors
2. **P0 (Critical)**: Add API logging
3. **P1 (High)**: Test all endpoints with curl
4. **P1 (High)**: Fix data model mismatches
5. **P2 (Medium)**: Test end-to-end flow
6. **P2 (Medium)**: Document missing endpoints
7. **P3 (Low)**: Optimize error handling
8. **P3 (Low)**: Configure mock flags

---

## 💡 Debugging Tips

### If preview doesn't show:
- Check console for `[RenderPreview]` logs
- Look for status code (200 vs 404 vs 500)
- Check if HTML is being received
- Verify HTML length > 0
- Check WebView constraints

### If optimize fails:
- Check console for `[API]` logs  
- Look for upload response
- Check if resume_id and job_description_id are returned
- Verify optimize request is being sent
- Check response format

### If design templates don't load:
- Check console for template API logs
- Verify category parameter is sent
- Check response format
- Look for empty array vs null

### If file permission error persists:
- Check selectedResumeURL is valid
- Verify file exists at path
- Check it's not /dev/null
- Look for security scoped resource issues

---

## 📝 Code to Review

Please review and fix:

1. **TailorViewModel.swift** (lines 80-81) - Compile errors
2. **APIClient.swift** - Add request/response logging
3. **ResumeOptimizationService.swift** - Add error handling
4. **ResumeDesignService.swift** - Verify renderPreview logic
5. **DomainModels.swift** - Check all DTOs have correct CodingKeys
6. **BackendConfig.swift** - Set appropriate mock flags

---

## 🚀 Expected Outcome

After completing these tasks:

- ✅ App compiles without errors
- ✅ All API calls are logged
- ✅ Know which endpoints work/don't work
- ✅ Preview shows optimized resume
- ✅ Design templates load correctly
- ✅ No file permission errors
- ✅ Clear path forward for missing features

---

**Let me know what you discover and what needs to be implemented!**
