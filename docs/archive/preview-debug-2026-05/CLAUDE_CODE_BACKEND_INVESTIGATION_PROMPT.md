# 🎯 CLAUDE CODE PROMPT: Real Backend Integration Investigation

**Context**: iOS resume builder app using SwiftUI. Currently configured to use real backend but optimized resume preview is not showing. Need to investigate why real backend integration isn't working and fix all issues.

---

## 📋 Current Situation

### App Configuration
- **Backend URL**: `https://www.resumelybuilderai.com`
- **Mock Services**: Currently disabled (`BackendConfig.useMockServices = false`)
- **Issue**: Optimized resume preview not showing after optimization
- **Expected**: After tapping "Optimize for This Job", should navigate to OptimizedResumeView with rendered resume preview

### Tech Stack
- **iOS App**: SwiftUI, Swift 6
- **Authentication**: Supabase Auth
- **Backend**: Node.js/Python (needs investigation)
- **API Communication**: REST APIs with JWT tokens

### Key Files
1. `BackendConfig.swift` - API base URL and service configuration
2. `ImproveView.swift` - Triggers optimization flow
3. `ImproveViewModel.swift` - Handles optimize API call
4. `OptimizedResumeView.swift` - Displays optimized resume
5. `OptimizedResumeViewModel.swift` - Manages resume sections and data loading
6. `ResumePreviewWebView.swift` - Renders HTML preview in WebView
7. `ResumeOptimizationService.swift` - Real backend service implementation
8. `ResumeDesignService.swift` - Real backend design/template service
9. `APIClient.swift` - HTTP client for API calls
10. `DomainModels.swift` - Data models and DTOs

---

## 🔍 Investigation Tasks

### Task 1: Verify Backend Endpoints Exist

**Check if these endpoints are implemented on the backend:**

1. **POST `/api/optimize`**
   - Purpose: Optimize resume for a job description
   - Expected Request:
     ```json
     {
       "resume_id": "uuid",
       "job_description_id": "uuid"
     }
     ```
   - Expected Response:
     ```json
     {
       "success": true,
       "optimization_id": "opt-123",
       "sections": [
         {
           "id": "s1",
           "type": "summary",
           "body": "Optimized summary text...",
           "status": "optimized"
         }
       ]
     }
     ```

2. **GET `/api/optimization/{id}`**
   - Purpose: Fetch optimization details and sections
   - Expected Response:
     ```json
     {
       "optimization_id": "opt-123",
       "sections": [...],
       "job_title": "Software Engineer",
       "company": "Tech Corp",
       "ats_score_before": 65,
       "ats_score_after": 82
     }
     ```

3. **POST `/api/design/render-preview`**
   - Purpose: Generate HTML preview of resume
   - Expected Request:
     ```json
     {
       "optimization_id": "opt-123",
       "template_id": "ats-clean",
       "customization": {
         "spacing": 0.5,
         "accent_color": "6366F1",
         "font_style": "modern"
       }
     }
     ```
   - Expected Response:
     ```json
     {
       "success": true,
       "preview_html": "<html>...</html>"
     }
     ```

4. **GET `/api/design/templates?category=traditional`**
   - Purpose: List available resume templates
   - Expected Response:
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

5. **GET `/api/download/{optimization_id}?fmt=pdf`**
   - Purpose: Download resume as PDF
   - Expected: PDF file binary

**Action**: For each endpoint, verify:
- ✅ Endpoint exists and is registered in routing
- ✅ Handles authentication (Bearer token)
- ✅ Returns expected response format
- ✅ Handles errors gracefully

---

### Task 2: Check Database Schema

**Verify these tables exist and have correct schema:**

1. **`optimizations` table**
   - `id` (uuid, primary key)
   - `user_id` (uuid, foreign key)
   - `resume_id` (uuid, foreign key)
   - `job_description_id` (uuid, foreign key)
   - `status` (enum: pending, completed, failed)
   - `ats_score_before` (integer)
   - `ats_score_after` (integer)
   - `job_title` (text)
   - `company` (text)
   - `created_at` (timestamp)
   - `updated_at` (timestamp)

2. **`optimization_sections` table**
   - `id` (uuid, primary key)
   - `optimization_id` (uuid, foreign key)
   - `type` (enum: summary, experience, education, skills, additional)
   - `body` (text)
   - `status` (enum: pending, optimized, improved)
   - `ai_note` (text, optional)
   - `order` (integer)

3. **`design_templates` table**
   - `id` (uuid, primary key)
   - `slug` (text, unique)
   - `name` (text)
   - `category` (enum: traditional, modern, creative, corporate)
   - `is_premium` (boolean)
   - `ats_score` (integer)
   - `thumbnail_url` (text, optional)

4. **`design_assignments` table**
   - `id` (uuid, primary key)
   - `optimization_id` (uuid, foreign key)
   - `template_id` (uuid, foreign key)
   - `customization` (jsonb)
   - `created_at` (timestamp)

**Action**:
- ✅ Check if tables exist
- ✅ Verify schema matches iOS app expectations
- ✅ Check foreign key constraints
- ✅ Verify indexes for performance

---

### Task 3: Trace API Call Flow

**Add logging to track requests:**

1. **In `APIClient.swift`**, add request/response logging:
   ```swift
   // Before making request
   print("📤 [API] \(method) \(endpoint.path)")
   print("📤 [API] Headers: \(request.allHTTPHeaderFields ?? [:])")
   if let body = request.httpBody {
       print("📤 [API] Body: \(String(data: body, encoding: .utf8) ?? "binary")")
   }
   
   // After receiving response
   print("📥 [API] Status: \(httpResponse.statusCode)")
   print("📥 [API] Response: \(String(data: data, encoding: .utf8) ?? "binary")")
   ```

2. **In `ResumeOptimizationService.swift`**, log optimize calls:
   ```swift
   func optimize(resumeId: String, jobDescriptionId: String, token: String) async throws -> OptimizeResponse {
       print("🔧 [OPTIMIZATION] Starting optimization")
       print("🔧 [OPTIMIZATION] ResumeId: \(resumeId)")
       print("🔧 [OPTIMIZATION] JobDescriptionId: \(jobDescriptionId)")
       
       // Make API call
       let response = try await apiClient.postJSON(...)
       
       print("✅ [OPTIMIZATION] Got response")
       print("✅ [OPTIMIZATION] OptimizationId: \(response.optimizationId ?? "nil")")
       print("✅ [OPTIMIZATION] Sections: \(response.sections?.count ?? 0)")
       
       return response
   }
   ```

3. **In `ResumeDesignService.swift`**, log template and preview calls

**Action**: Add comprehensive logging to trace entire flow from iOS → Backend → iOS

---

### Task 4: Check Authentication Flow

**Verify Supabase token is being sent correctly:**

1. **In `AuthService.swift`**, check token retrieval:
   ```swift
   print("🔐 [AUTH] Getting access token")
   let token = try await supabase.auth.session.accessToken
   print("🔐 [AUTH] Token: \(token.prefix(20))...")
   print("🔐 [AUTH] Token length: \(token.count)")
   ```

2. **Backend verification**:
   - Check if backend is validating JWT tokens correctly
   - Verify token isn't expired
   - Check if user_id is being extracted from token

3. **Common issues**:
   - Token format: Should be `Bearer {token}`, not just `{token}`
   - Token expiry: Tokens expire after 1 hour by default
   - Token refresh: Need to refresh expired tokens

**Action**: Add auth logging and verify token flow end-to-end

---

### Task 5: Check Error Handling

**Identify where errors are being swallowed:**

1. **In `OptimizedResumeViewModel.swift`**, check `loadSections`:
   ```swift
   func loadSections(appState: AppState) async {
       guard sections.isEmpty, !isLoadingSections else { return }
       isLoadingSections = true
       defer { isLoadingSections = false }
       do {
           try await appState.callWithFreshToken { token in
               try await self.loadSections(with: token)
           }
       } catch {
           errorMessage = error.localizedDescription
           print("❌ [LOAD SECTIONS] Error: \(error)")
           print("❌ [LOAD SECTIONS] Error type: \(type(of: error))")
       }
   }
   ```

2. **Check if errors are displayed in UI**:
   - Look for `errorMessage` bindings in SwiftUI
   - Verify Text views are showing errors
   - Check if errors are hidden off-screen

**Action**: Add error logging everywhere and ensure errors surface to UI

---

### Task 6: Test with curl/Postman

**Manually test backend endpoints:**

```bash
# 1. Get auth token (login first via Supabase)
# Replace with actual token from app

export TOKEN="your-supabase-jwt-token-here"
export BASE_URL="https://www.resumelybuilderai.com"

# 2. Test health endpoint
curl -X GET "$BASE_URL/api/health"

# 3. Test optimize endpoint
curl -X POST "$BASE_URL/api/optimize" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "resume_id": "test-resume-id",
    "job_description_id": "test-jd-id"
  }'

# 4. Test get optimization (replace {id} with real ID)
curl -X GET "$BASE_URL/api/optimization/{id}" \
  -H "Authorization: Bearer $TOKEN"

# 5. Test render preview
curl -X POST "$BASE_URL/api/design/render-preview" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "optimization_id": "test-opt-id",
    "template_id": "ats-clean",
    "customization": {
      "spacing": 0.5,
      "accent_color": "6366F1",
      "font_style": "modern"
    }
  }'

# 6. Test get templates
curl -X GET "$BASE_URL/api/design/templates?category=traditional" \
  -H "Authorization: Bearer $TOKEN"
```

**Expected Results**:
- All endpoints return 200 OK (or appropriate status)
- No 404 (endpoint not found)
- No 401 (unauthorized)
- No 500 (server error)

**Action**: Test each endpoint manually and document results

---

### Task 7: Check Backend Implementation

**For each endpoint, verify:**

1. **POST `/api/optimize`**
   ```typescript
   // Example backend implementation check
   router.post('/optimize', authMiddleware, async (req, res) => {
     const { resume_id, job_description_id } = req.body;
     const userId = req.user.id; // From JWT
     
     // ✅ Check: Does this exist?
     // ✅ Check: Is it calling AI service?
     // ✅ Check: Is it saving to database?
     // ✅ Check: Is it returning correct format?
     
     const optimization = await optimizeResume(userId, resume_id, job_description_id);
     
     res.json({
       success: true,
       optimization_id: optimization.id,
       sections: optimization.sections
     });
   });
   ```

2. **Check database queries are working**:
   - Test SELECT queries
   - Test INSERT queries
   - Check for SQL errors in logs

3. **Check AI integration**:
   - Is OpenAI/GPT API key configured?
   - Are API calls succeeding?
   - Are responses being parsed correctly?

**Action**: Review backend code for each critical endpoint

---

### Task 8: Network Diagnostics

**Check network layer:**

1. **SSL/TLS issues**:
   - Is backend using valid SSL certificate?
   - Is certificate chain complete?
   - Try with `curl -v` to see SSL handshake

2. **CORS issues** (if using web preview):
   - Check CORS headers on backend
   - Ensure iOS origin is allowed

3. **Timeout issues**:
   - Check if requests are timing out
   - Increase timeout if optimization takes >30s
   - Add progress updates for long operations

4. **Connection issues**:
   - Can iOS simulator reach backend?
   - Try `ping www.resumelybuilderai.com`
   - Check firewall rules

**Action**: Run network diagnostics and fix connectivity issues

---

### Task 9: iOS App State Management

**Check app state flow:**

1. **Navigation state**:
   ```swift
   // Is navigation being triggered?
   @State private var navigateToOptimized = false
   
   // Is state being set correctly?
   navigateToOptimized = true // ← Check this happens
   
   // Is navigationDestination bound?
   .navigationDestination(isPresented: $navigateToOptimized) {
     OptimizedResumeView(...)
   }
   ```

2. **Data passing**:
   ```swift
   // Are sections being passed in init?
   OptimizedResumeViewModel(
     optimizationId: currentOptId,  // ← Not nil?
     sections: optimizedSections     // ← Not empty?
   )
   ```

3. **View lifecycle**:
   - Is `.task` being called?
   - Is `loadSections` being invoked?
   - Are state updates triggering view refreshes?

**Action**: Verify iOS state management is correct

---

### Task 10: HTML Preview Rendering

**If HTML is returned but not displaying:**

1. **Check HTML is valid**:
   ```swift
   print("HTML preview:")
   print(html.prefix(500)) // Print first 500 chars
   ```

2. **Check WebView setup**:
   - Is baseURL correct?
   - Is HTML string not empty?
   - Are there JavaScript errors?

3. **Check layout constraints**:
   - Is WebView frame zero-size?
   - Is `.aspectRatio(8.5 / 11)` causing issues?
   - Try removing aspectRatio temporarily

**Action**: Debug WebView rendering issues

---

## 🎯 Deliverables

After investigation, provide:

### 1. Backend Status Report
- ✅/❌ Each endpoint exists and works
- ✅/❌ Database schema is correct
- ✅/❌ Authentication is working
- ✅/❌ AI integration is working

### 2. Error Log
- List all errors found in console
- HTTP status codes received
- Exception stack traces
- Network errors

### 3. Missing Implementations
- List endpoints that don't exist
- List database tables that are missing
- List features not implemented

### 4. Fixes Applied
- Code changes made to iOS app
- Code changes made to backend
- Configuration changes
- Database migrations needed

### 5. Testing Results
- curl/Postman test results
- iOS app test results
- Screenshots of working flow
- Console logs of successful flow

---

## 📝 Recommended Fix Priority

1. **Priority 1 (Blocking)**: Backend endpoints missing → Implement them
2. **Priority 2 (Blocking)**: Database schema wrong → Run migrations
3. **Priority 3 (Critical)**: Authentication broken → Fix token validation
4. **Priority 4 (Important)**: HTML preview not rendering → Debug WebView
5. **Priority 5 (Nice to have)**: Error messages not showing → Improve UX

---

## 🔧 Quick Wins

If you find these issues, here are quick fixes:

### Issue: Endpoint returns 404
**Fix**: Implement the endpoint on backend or check routing configuration

### Issue: Endpoint returns 401
**Fix**: Check token format (should include "Bearer "), verify token isn't expired

### Issue: Endpoint returns 500
**Fix**: Check backend logs for exception, fix the bug causing crash

### Issue: Data format mismatch
**Fix**: Update backend response to match iOS models or update iOS models to match backend

### Issue: Database empty
**Fix**: Seed database with test data or implement data creation flow

---

## 💡 Example Working Flow

When everything works, this is what should happen:

```
1. User taps "Optimize for This Job"
   → POST /api/optimize with resume_id and job_description_id
   
2. Backend receives request
   → Validates auth token ✅
   → Fetches resume and job description from DB ✅
   → Calls GPT API to optimize resume ✅
   → Saves optimization and sections to DB ✅
   → Returns optimization_id and sections ✅
   
3. iOS receives response
   → Parses OptimizeResponse ✅
   → Extracts optimization_id and sections ✅
   → Navigates to OptimizedResumeView ✅
   
4. OptimizedResumeView appears
   → Sections already loaded (passed in init) ✅
   → Displays sections in preview ✅
   → Bottom bar shows "Refine", "Expert", "Design" ✅
   
5. Preview renders
   → POST /api/design/render-preview ✅
   → Backend returns HTML ✅
   → WebView displays HTML ✅
   → User sees styled resume ✅
```

---

## 🚀 Next Steps

1. **Start with curl tests** - Verify each endpoint works manually
2. **Add comprehensive logging** - iOS app and backend
3. **Test with real data** - Create a test resume and job description
4. **Fix issues in order** - Start with Priority 1, work down
5. **Verify end-to-end** - Test complete flow from upload to preview

---

**Questions to Answer**:
- Is the backend running and accessible?
- Do all required endpoints exist?
- Is authentication working correctly?
- Are database tables created and populated?
- Are API responses in the correct format?
- Is the iOS app parsing responses correctly?
- Is navigation working properly?
- Is the HTML preview rendering?

**Success Criteria**:
- User can optimize resume
- Optimized resume appears with content
- Preview shows styled HTML
- No errors in console
- All buttons work correctly

