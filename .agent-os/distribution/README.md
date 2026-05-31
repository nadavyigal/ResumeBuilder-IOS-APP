# ResumeBuilder Project-Level Distribution Scaffold

Copy these files into the ResumeBuilder repo at `.agent-os/distribution/`. They are the project-level distribution OS for ResumeBuilder AI.

## How To Install

From inside the ResumeBuilder repo:

```
mkdir -p .agent-os/distribution
cp -R "/Users/nadavyigal/Documents/Projects /Agentic OS/distribution-os/projects/resumebuilder/scaffold/"* .agent-os/distribution/
mkdir -p .agents
cp .agent-os/distribution/product-positioning.md .agents/product-marketing.md
```

After install, edit each file to reflect the current state of ResumeBuilder. The global Distribution OS reads these files when running workflows.

## Files In This Scaffold

- `README.md` (this file)
- `product-positioning.md` — used by every marketing skill as the foundation
- `audience.md`
- `channels.md`
- `messaging.md`
- `competitors.md`
- `app-store-program.md` — primary, iOS App Store optimization
- `seo-program.md` — web pages that feed App Store install
- `lifecycle-program.md`
- `gtm-plan.md` — populated by `distribution-os/workflows/13-gtm-plan.md`
- `directories.md`
- `experiment-backlog.md`
- `weekly-plan.md`
- `metrics.md`
- `assets-needed.md`
- `lessons.md`
- `hebrew-program.md`

## iOS Focus Note

The model is iOS-first. Web exists as a feeder to App Store install. `app-store-program.md` is the primary program file; `seo-program.md` defines web landings whose primary CTA is the App Store. Programmatic SEO is now Tier B until ASO and bespoke landings prove install conversion.
