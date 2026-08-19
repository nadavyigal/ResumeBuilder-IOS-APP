# 🎯 PROMPT FOR CLAUDE CODE

Copy and paste this into Claude Code:

---

I need help investigating why the optimized resume preview isn't showing in my iOS SwiftUI app when using the real backend (not mocks).

**Current Setup:**
- iOS app in SwiftUI + Swift 6
- Backend at `https://www.resumelybuilderai.com`
- Using Supabase for auth
- `BackendConfig.useMockServices = false` (want to use real backend)

**Problem:**
After tapping "Optimize for This Job", the app should navigate to OptimizedResumeView and show the resume preview, but nothing appears.

**Investigation Needed:**

1. **Check if backend endpoints exist and work:**
   - `POST /api/optimize` - Optimize resume
   - `GET /api/optimization/{id}` - Get optimization details
   - `POST /api/design/render-preview` - Generate HTML preview
   - `GET /api/design/templates?category=traditional` - Get templates
   - `GET /api/download/{id}?fmt=pdf` - Download PDF

2. **Add comprehensive logging:**
   - In `APIClient.swift` - Log all HTTP requests/responses
   - In `ResumeOptimizationService.swift` - Log optimize calls
   - In `ResumeDesignService.swift` - Log preview rendering
   - In `OptimizedResumeViewModel.swift` - Log section loading
   - In `ResumePreviewWebView.swift` - Already has logging

3. **Test endpoints with curl:**
   ```bash
   curl -X POST "https://www.resumelybuilderai.com/api/optimize" \
     -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"resume_id": "test", "job_description_id": "test"}'
   ```

4. **Check database schema:**
   - `optimizations` table exists with correct columns?
   - `optimization_sections` table exists?
   - `design_templates` table has data?

5. **Verify authentication:**
   - Token is being sent correctly?
   - Backend validates JWT properly?
   - Token isn't expired?

6. **Check iOS data flow:**
   - Does `ImproveViewModel.optimize()` return data?
   - Is `navigateToOptimized` being set to true?
   - Are sections being passed to `OptimizedResumeViewModel`?
   - Is `ResumePreviewWebView` receiving optimizationId?

**Expected API Responses:**

POST /api/optimize should return:
```json
{
  "success": true,
  "optimization_id": "opt-123",
  "sections": [
    {"id": "s1", "type": "summary", "body": "...", "status": "optimized"}
  ]
}
```

GET /api/optimization/{id} should return:
```json
{
  "optimization_id": "opt-123",
  "sections": [...],
  "job_title": "Software Engineer",
  "ats_score_before": 65,
  "ats_score_after": 82
}
```

POST /api/design/render-preview should return:
```json
{
  "success": true,
  "preview_html": "<html>...</html>"
}
```

**Files to investigate:**
- `BackendConfig.swift` - API configuration
- `APIClient.swift` - HTTP client
- `ResumeOptimizationService.swift` - Optimize API calls
- `ResumeDesignService.swift` - Design API calls
- `ImproveView.swift` - UI for optimize button
- `ImproveViewModel.swift` - Optimize logic
- `OptimizedResumeView.swift` - Result screen
- `OptimizedResumeViewModel.swift` - Data loading
- `ResumePreviewWebView.swift` - Preview rendering
- `DomainModels.swift` - Data models

**What I need from you:**

1. Add detailed logging to all API calls (request + response)
2. Test each backend endpoint with curl or implement if missing
3. Trace the complete data flow from button tap to preview display
4. Identify exactly where the flow is breaking (iOS side or backend side)
5. Provide fixes for any issues found
6. Ensure error messages are displayed to user if something fails

**Priority:**
1. First, verify backend endpoints exist and work (curl tests)
2. Then add logging to iOS app to see what's happening
3. Test end-to-end and fix any issues found

Let me know what you discover and what fixes are needed!
