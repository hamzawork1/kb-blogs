# mhamza.space — Learning Kit

A self-contained learning path for understanding **everything that was set up in this project**, why each choice was made, and how to operate the site day-to-day without re-learning the plumbing.

Target reader: a cloud / DevOps / SRE-leaning engineer who has just cloned the repo or come back after weeks away.

---

## How to read this kit

If you're brand new, read in order. If you came back to do one specific thing, jump to the right section.

| # | File | What you'll learn | Roughly |
|---|---|---|---|
| 00 | **You're here.** | Map of the kit and reading order. | 2 min |
| 01 | [`01-overview.md`](./01-overview.md) | What this project is, the tech stack, and the operating model in one diagram. | 5 min |
| 02 | [`02-tooling-primer.md`](./02-tooling-primer.md) | The minimum you need to know about Astro, Cloudflare Workers + assets, pnpm, Git workflow, and GitHub Actions to understand the rest. | 15 min |
| 03 | [`03-architecture.md`](./03-architecture.md) | How the site is wired internally — the Spectre integration, content collections, file-based routing, the build target. | 15 min |
| 04 | [`04-setup-journey.md`](./04-setup-journey.md) | The chronological story of building this. Every step, every rationale, the things that almost went sideways. Read this once for context, never re-read it. | 25 min |
| 05 | [`05-ci-cd-pipeline.md`](./05-ci-cd-pipeline.md) | `.github/workflows/ci-cd.yml` taken apart line by line. Secrets, environments, why each pin matters, the three real-world failures we hit. | 20 min |
| 06 | [`06-daily-workflows.md`](./06-daily-workflows.md) | **The one you'll re-open the most.** How to add a post, project, tag, image; how to edit; how to unpublish. With a complete worked example. | 20 min |
| 07 | [`07-theme-structure.md`](./07-theme-structure.md) | Where to change what — sidebar items, colors, code highlighting, layout, cover banners, profile picture. | 10 min |
| 08 | [`08-troubleshooting.md`](./08-troubleshooting.md) | "It used to work" — common failures and how to diagnose them. Build errors, deploy errors, lint, search empty, 404s. | 10 min |
| 09 | [`09-decisions.md`](./09-decisions.md) | Narrative version of every architecture decision. Read this when someone asks "why didn't you just use X?" | 15 min |

Total cover-to-cover: ~2 hours of focused reading. After that you should not need to touch infrastructure again — just content.

---

## Suggested reading paths

### "I just cloned the repo, what is this?"
01 → 02 → 03 → 04. Then skim 09 for the why.

### "I want to publish a post"
06 (only). Maybe 08 if something breaks.

### "The deploy is broken / pipeline failed"
08 → 05.

### "I want to redesign the home page"
07 → 03.

### "I want to migrate the host / package manager / pipeline"
09 (start with the reversibility section of each ADR narrative) → 04.

---

## Relationship to the other docs in this repo

| Doc | Purpose | Status |
|---|---|---|
| `README.md` | Public-facing project intro for visitors / GitHub viewers. | Stays minimal — points at this kit. |
| `CHANGELOG.md` | Dated log of what changed when. Updated per release. | Live, append-only. |
| `docs/decisions/0001..0003-*.md` | Per-decision ADRs in standard format (Status, Context, Decision, Alternatives, Consequences, Reversibility). | Source-of-truth for individual decisions. The 09 doc here is a narrative bridge. |
| `docs/runbooks/deploy-cloudflare-pages.md` | Step-by-step Cloudflare + secrets + first deploy runbook with troubleshooting. | Operational. |
| `docs/runbooks/new-post.md` | Step-by-step "publish a post" runbook with commands. | Operational. |
| `CLAUDE.md` (gitignored) | Local mental-model file for Claude Code agent sessions. | Personal-machine only. |

This kit (`docs/learning/`) is the **why and the how-it-all-fits-together**. The runbooks (`docs/runbooks/`) are the **exact steps for one task**. The ADRs (`docs/decisions/`) are the **single-decision deep-dives**. Use whichever matches what you're doing.
