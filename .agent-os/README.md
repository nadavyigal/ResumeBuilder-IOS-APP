# Agent OS — ResumeBuilder iOS

> This directory contains the detailed workflow, standards, and template files for the Agent OS.
> Do not load all files at once. Load only what your current task requires (see AGENTS.md routing table).

## Directory Structure

```
.agent-os/
├── README.md           ← You are here
├── standards/          ← How to write good code for this project
│   ├── swiftui-standards.md
│   ├── ios-architecture-standards.md
│   ├── mobile-ux-standards.md
│   ├── resume-quality-standards.md
│   ├── ai-output-standards.md
│   ├── template-quality-standards.md
│   ├── pdf-export-standards.md
│   ├── testing-standards.md
│   ├── app-store-standards.md
│   └── security-and-config-standards.md
├── workflows/          ← Step-by-step processes for common tasks
│   ├── feature-planning.md
│   ├── story-implementation.md
│   ├── bug-fix.md
│   ├── ios-qa-review.md
│   ├── resume-output-review.md
│   ├── testflight-review.md
│   ├── pr-review.md
│   ├── progress-update.md
│   └── self-improvement.md
└── templates/          ← Fill-in-the-blank starting points for documents
    ├── product-brief-template.md
    ├── feature-spec-template.md
    ├── dev-story-template.md
    ├── ios-qa-report-template.md
    ├── resume-output-review-template.md
    ├── testflight-report-template.md
    ├── pr-summary-template.md
    ├── bug-report-template.md
    ├── progress-report-template.md
    └── lesson-template.md
```

## When to Load These Files

- **Planning:** Load `workflows/feature-planning.md` + relevant product/architecture docs
- **Implementing:** Load `workflows/story-implementation.md` + approved spec
- **Bug fixing:** Load `workflows/bug-fix.md` + relevant source files
- **QA:** Load `workflows/ios-qa-review.md` + `docs/qa/ios-qa-checklist.md`
- **TestFlight:** Load `workflows/testflight-review.md` + `docs/qa/testflight-checklist.md`
- **PR:** Load `workflows/pr-review.md` + `templates/pr-summary-template.md`
- **Standards reference:** Load only the specific standard needed (e.g., `standards/swiftui-standards.md` when writing SwiftUI)

## Token Efficiency

This OS is designed to stay out of your way. You should never need to read more than 3–4 files from this directory in a single session. If you find yourself loading 8+ files, you are probably over-engineering the approach.
