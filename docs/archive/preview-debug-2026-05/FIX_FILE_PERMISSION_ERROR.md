# 🔴 CRITICAL: File Permission Error & Saved Resume Issues - FIXED

**Error**: "The file 'null' couldn't be opened because you don't have permission"

---

## 🎯 Root Cause Analysis

### Issue #1: Cancel Button Passes Invalid URL

**File**: `SavedResumePickerSheet.swift` line 48

**Current Code (BROKEN)**:
```swift
Button("Cancel") {
    onSelect(URL(fileURLWithPath: "/dev/null"), "")
}
```

**Problem**: 
- When user taps "Cancel", it calls `onSelect` with an invalid URL: `/dev/null`
- This URL is then passed to `viewModel.useLibraryResume(localURL: localURL, displayName: displayName)`
- Later, when user tries to optimize, the app tries to upload `/dev/null`
- Result: "The file 'null' couldn't be opened because you don't have permission"

**Why This Happens**:
1. User taps "Use a saved resume" button
2. SavedResumePickerSheet opens
3. User taps "Cancel" instead of selecting a resume
4. `onSelect(URL(fileURLWithPath: "/dev/null"), "")` is called
5. `TailorViewModel.useLibraryResume()` sets `selectedResumeURL = URL("/dev/null")`
6. User taps "Optimize" without selecting another file
7. App tries to read `/dev/null` → Permission denied!

---

### Issue #2: Saved Resumes Using Mock Data

**File**: `BackendConfig.swift` line 9

**Current Setting**:
```swift
static let useMockLibraryService = true  // ← Mock data only!
```

**Problem**:
- Library service is using **mock data**, not real backend
- Saved resumes won't persist or sync across devices
- Can't actually save or retrieve resumes from server

---

## ✅ Fix #1: Proper Cancel Handling in SavedResumePickerSheet

The Cancel button should **dismiss the sheet without changing anything**, not pass a dummy URL.

### Solution A: Don't Call onSelect on Cancel (Recommended)

```swift
.sheet(isPresented: $showLibraryPicker) {
    SavedResumePickerSheet(
        libraryViewModel: libraryViewModel,
        onSelect: { localURL, displayName in
            viewModel.useLibraryResume(localURL: localURL, displayName: displayName)
            showLibraryPicker = false
        }
    )
    .environment(appState)
}
```

Change `SavedResumePickerSheet.swift`:

```swift
// BEFORE (WRONG):
.toolbar {
    ToolbarItem(placement: .cancellationAction) {
        Button("Cancel") {
            onSelect(URL(fileURLWithPath: "/dev/null"), "")
        }
    }
}

// AFTER (CORRECT):
@Environment(\.dismiss) private var dismiss

// ... in toolbar:
.toolbar {
    ToolbarItem(placement: .cancellationAction) {
        Button("Cancel") {
            dismiss()  // Just dismiss without calling onSelect
        }
    }
}
```

### Solution B: Add isPresented Binding (Alternative)

```swift
// Change SavedResumePickerSheet to accept binding
struct SavedResumePickerSheet: View {
    @Binding var isPresented: Bool
    @Bindable var libraryViewModel: ResumeLibraryViewModel
    var onSelect: (URL, String) -> Void
    
    // ...
    
    .toolbar {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                isPresented = false  // Just close the sheet
            }
        }
    }
}
```

---

## ✅ Fix #2: Add Validation in TailorViewModel

Even with the fix above, we should **validate the URL** before using it:

**File**: `TailorViewModel.swift`

Add validation in `useLibraryResume`:

```swift
// BEFORE:
func useLibraryResume(localURL: URL, displayName: String) {
    selectedResumeURL = localURL
    selectedResumeName = displayName
}

// AFTER:
func useLibraryResume(localURL: URL, displayName: String) {
    // Validate URL is not /dev/null or empty
    guard localURL.path != "/dev/null",
          !displayName.isEmpty,
          FileManager.default.fileExists(atPath: localURL.path) else {
        print("⚠️ [TAILOR] Invalid resume URL: \(localURL.path)")
        return
    }
    
    selectedResumeURL = localURL
    selectedResumeName = displayName
    print("✅ [TAILOR] Library resume selected: \(displayName) at \(localURL.path)")
}
```

Add validation in `optimize`:

```swift
func optimize(appState: AppState) async {
    guard let selectedResumeURL else {
        errorMessage = "Choose a PDF resume first."
        return
    }
    
    // Validate the file actually exists
    guard FileManager.default.fileExists(atPath: selectedResumeURL.path) else {
        errorMessage = "The selected resume file no longer exists. Please choose another file."
        selectedResumeURL = nil
        selectedResumeName = nil
        return
    }
    
    // Validate it's not /dev/null
    guard selectedResumeURL.path != "/dev/null" else {
        errorMessage = "Please select a valid resume file."
        selectedResumeURL = nil
        selectedResumeName = nil
        return
    }

    let trimmedDescription = jobDescription.trimmingCharacters(in: .whitespacesAndNewlines)
    // ... rest of function
}
```

---

## ✅ Fix #3: Enable Real Library Service (When Backend Ready)

**File**: `BackendConfig.swift`

```swift
// Change line 9:
// BEFORE:
static let useMockLibraryService = true

// AFTER (when backend endpoints exist):
static let useMockLibraryService = false
```

**But first**, verify these endpoints exist on backend:
- `GET /api/v1/resumes` - List saved resumes
- `POST /api/v1/resumes/{id}/save` - Save a resume
- `DELETE /api/v1/resumes/{id}` - Delete
- `PUT /api/v1/resumes/{id}/rename` - Rename
- `GET /api/v1/resumes/{id}/download` - Download PDF

---

## 📝 Complete Fix Implementation

### Step 1: Fix SavedResumePickerSheet.swift

```swift
import SwiftUI

struct SavedResumePickerSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss  // ← ADD THIS
    @Bindable var libraryViewModel: ResumeLibraryViewModel
    var onSelect: (URL, String) -> Void

    @State private var isDownloading: String? = nil
    @State private var downloadError: String?

    var body: some View {
        NavigationStack {
            Group {
                if libraryViewModel.isLoading {
                    ProgressView("Loading saved resumes…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if libraryViewModel.resumes.isEmpty {
                    ContentUnavailableView(
                        "No saved resumes",
                        systemImage: "books.vertical",
                        description: Text("Resumes you save after uploading will appear here.")
                    )
                } else {
                    List {
                        ForEach(libraryViewModel.resumes) { resume in
                            resumeRow(resume)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        if let token = appState.session?.accessToken {
                                            Task { await libraryViewModel.delete(id: resume.id, token: token) }
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Saved Resumes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()  // ← CHANGED: Just dismiss, don't call onSelect
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func resumeRow(_ resume: SavedResume) -> some View {
        let displayName = resume.displayName ?? resume.filename
        let isThisDownloading = isDownloading == resume.id

        Button {
            guard !isThisDownloading else { return }
            Task {
                guard let token = appState.session?.accessToken else { return }
                isDownloading = resume.id
                downloadError = nil
                do {
                    let localURL = try await libraryViewModel.downloadToCache(resume: resume, token: token)
                    isDownloading = nil
                    onSelect(localURL, displayName)
                    dismiss()  // ← ADD THIS: Dismiss after selection
                } catch {
                    isDownloading = nil
                    downloadError = "Download failed: \(error.localizedDescription)"
                }
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Theme.accent.opacity(0.12))
                        .frame(width: 38, height: 38)
                    Image(systemName: "doc.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.accent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if let size = resume.sizeBytes {
                        Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if isThisDownloading {
                    ProgressView()
                        .scaleEffect(0.85)
                } else {
                    Image(systemName: "arrow.down.circle")
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SavedResumePickerSheet(
        libraryViewModel: ResumeLibraryViewModel(service: MockResumeLibraryService()),
        onSelect: { _, _ in }
    )
    .environment(AppState())
}
```

### Step 2: Add Validation in TailorViewModel.swift

```swift
/// Pre-fills Step 1 from a file URL already downloaded from the library.
func useLibraryResume(localURL: URL, displayName: String) {
    // Validate URL is not /dev/null or invalid
    guard localURL.path != "/dev/null",
          !displayName.isEmpty,
          FileManager.default.fileExists(atPath: localURL.path) else {
        print("⚠️ [TAILOR] Invalid resume URL: \(localURL.path)")
        return
    }
    
    selectedResumeURL = localURL
    selectedResumeName = displayName
    print("✅ [TAILOR] Library resume selected: \(displayName)")
}

func optimize(appState: AppState) async {
    guard let selectedResumeURL else {
        errorMessage = "Choose a PDF resume first."
        return
    }
    
    // Validate the file actually exists and is not /dev/null
    guard selectedResumeURL.path != "/dev/null",
          FileManager.default.fileExists(atPath: selectedResumeURL.path) else {
        errorMessage = "The selected resume file is invalid. Please choose another file."
        selectedResumeURL = nil
        selectedResumeName = nil
        return
    }

    let trimmedDescription = jobDescription.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedURL = jobDescriptionURL.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedDescription.isEmpty || !trimmedURL.isEmpty else {
        errorMessage = "Paste a job description or add a job link."
        return
    }

    guard appState.session?.accessToken != nil else {
        errorMessage = "Please sign in first."
        return
    }

    isOptimizing = true
    errorMessage = nil
    reviewId = nil
    optimizationId = nil
    defer { isOptimizing = false }

    do {
        // Step 1 — upload PDF + job context
        let upload = try await appState.callWithFreshToken { token in
            try await self.apiClient.uploadResume(
                fileURL: selectedResumeURL,
                jobDescription: trimmedDescription.isEmpty ? nil : trimmedDescription,
                jobDescriptionURL: trimmedURL.isEmpty ? nil : trimmedURL,
                token: token
            )
        }
        uploadResponse = upload

        // ... rest of function unchanged
    } catch {
        errorMessage = error.localizedDescription
    }
}
```

### Step 3: Update TailorView.swift (No Changes Needed)

The TailorView already handles this correctly:

```swift
.sheet(isPresented: $showLibraryPicker) {
    SavedResumePickerSheet(
        libraryViewModel: libraryViewModel,
        onSelect: { localURL, displayName in
            viewModel.useLibraryResume(localURL: localURL, displayName: displayName)
            showLibraryPicker = false  // ← This will still close the sheet
        }
    )
    .environment(appState)
}
```

With the `dismiss()` call added to SavedResumePickerSheet, the sheet will close properly both on selection and on cancel.

---

## 🧪 Testing Checklist

### Test 1: Cancel Button
- [ ] Tap "Use a saved resume"
- [ ] Library picker appears
- [ ] Tap "Cancel"
- [ ] Sheet dismisses
- [ ] No resume is selected (Step 1 still says "PDF, up to 5 MB")
- [ ] Tap "Optimize" → Should show "Choose a PDF resume first"

### Test 2: Select Saved Resume
- [ ] Tap "Use a saved resume"
- [ ] Library picker appears
- [ ] Tap a resume
- [ ] Download starts (spinner shows)
- [ ] Sheet dismisses after download
- [ ] Step 1 shows resume name
- [ ] Can optimize successfully

### Test 3: File Picker After Cancel
- [ ] Tap "Use a saved resume"
- [ ] Tap "Cancel"
- [ ] Tap "Upload Resume" (document picker)
- [ ] Select a file
- [ ] Step 1 shows selected file
- [ ] Can optimize successfully

### Test 4: Invalid File Protection
- [ ] Try to optimize without selecting file → Proper error message
- [ ] Try to optimize with deleted file → Proper error message
- [ ] Try to optimize with /dev/null (shouldn't happen now) → Proper error message

---

## 🎯 Expected Results

### Before Fix:
```
1. User taps "Use a saved resume"
2. User taps "Cancel"
3. selectedResumeURL = /dev/null ❌
4. User enters job description
5. User taps "Optimize"
6. Error: "The file 'null' couldn't be opened" ❌
```

### After Fix:
```
1. User taps "Use a saved resume"
2. User taps "Cancel"
3. Sheet dismisses, nothing changes ✅
4. User enters job description
5. User taps "Optimize"
6. Error: "Choose a PDF resume first" ✅ (Helpful message)
```

**OR** if user selects a resume:

```
1. User taps "Use a saved resume"
2. User selects "My Resume.pdf"
3. Download starts and completes ✅
4. Sheet dismisses ✅
5. Step 1 shows "My Resume.pdf" ✅
6. User taps "Optimize"
7. Optimization works! ✅
```

---

## 📊 File Changes Summary

### Files to Modify:

1. **SavedResumePickerSheet.swift**
   - Add `@Environment(\.dismiss)` 
   - Change Cancel button to call `dismiss()` instead of `onSelect`
   - Add `dismiss()` call after successful selection

2. **TailorViewModel.swift**
   - Add validation in `useLibraryResume()` to reject `/dev/null`
   - Add file existence checks in `optimize()`
   - Add better error messages

3. **BackendConfig.swift** (Future)
   - Change `useMockLibraryService = false` when backend ready

---

## ✅ Priority Actions

**CRITICAL (Do Now)**:
1. Fix SavedResumePickerSheet Cancel button
2. Add validation in TailorViewModel

**IMPORTANT (Later)**:
3. Implement backend library endpoints
4. Enable real library service

---

**Status**: 🟢 **FIXES READY TO APPLY**

Apply these changes, rebuild, and test! The permission error should be completely resolved.

