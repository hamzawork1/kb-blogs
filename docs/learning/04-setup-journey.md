# 04 — Setup journey

This file is the chronological story of how this project went from "I cloned a theme" to "the staging site is live at staging.mhamza.space behind a real pipeline".

It exists because the *current state* of the repo doesn't show you the journey — Git history was rewritten on 2026-05-25 into a single clean root commit. The why-we-did-each-thing is preserved here instead.

Read it once. You should not need to come back to this file unless you're trying to understand why a particular choice was made and the ADRs don't have enough flavour.

---

## Phase 0 — Starting point

The project began with a clone of the Spectre Astro theme. Spectre is the work of @louisescher (MIT-licensed) — a terminal-inspired dark theme. It ships with reasonable defaults: a home page with a profile card / quick info / socials / about / projects / posts, a blog list, individual post pages with a TOC, sitemap, search via Pagefind, and optional Giscus comments.

The repo on GitHub at that point was `hamzawork1/kb-blogs`. The first commit was the unmodified theme. The site was branded "Spectre" and showed the theme author's example content.

Goal coming in: turn this into **mhamza.space**, a personal Azure / DevOps blog, with a real pipeline, deployed on Cloudflare, owned end-to-end by Hamza.

---

## Phase 1 — Make the site actually be Hamza's

### Step 1.1 — Fix the broken dev server

The first attempt at `pnpm dev` failed with:

```
ERROR: It seems you have not updated the preset Giscus configuration for comments!
Please change the settings in your astro.config.mjs ...
```

The theme's integration validates its options at startup. The default `astro.config.ts` passes a `giscus: { ... }` object whose fields are all empty (placeholders meant to be filled in via `.env`). The integration treats "all empty" as a configuration error to keep people from accidentally deploying with broken comments.

**Decision:** disable Giscus for now (set `giscus: false` in `astro.config.ts`) and keep the env-var loading code commented out for when comments become a priority. The reasoning: don't ship a feature you haven't decided you want.

### Step 1.2 — Switch from the SSH remote to HTTPS

The repo's `origin` was set to `git@github.com:hamzawork1/kb-blogs.git`. The local machine's SSH key wasn't registered on the `hamzawork1` GitHub account, so `git push` failed with `Permission denied (publickey)`.

**Decision:** switch the remote to HTTPS and authenticate via `gh auth login`. The reasoning: HTTPS + the GitHub CLI's credential helper is the lowest-friction path on Windows. SSH would have been equally valid but requires copying the public key into GitHub's settings — one extra step we didn't need.

### Step 1.3 — Replace the theme's content with Hamza's

The theme came with `info.json`, `socials.json`, `work.json` placeholders that pointed at "1 year old", "Made in Germany", the original author's GitHub, etc. The `about.mdx` was the theme's marketing copy. The `getting-started.mdx` was the theme's setup guide. There was a `spectre.mdx` project entry showcasing the theme.

We replaced all of this:

- `info.json` → Hamza's role, location ("Remote / Worldwide"), tech focus
- `socials.json` → real GitHub, LinkedIn, email
- `work.json` → placeholder entry (Hamza chose to fill this in himself later)
- `about.mdx` → short bio
- `getting-started.mdx` → deleted (the *learning kit* you're reading now is a much better successor)
- `spectre.mdx` → deleted

### Step 1.4 — Configure site-wide identity

`astro.config.ts` was updated to pass `name: "Muhammad Hamza"`, `site: "https://mhamza.space"`, and `openGraph` defaults that describe Hamza's site instead of the theme.

This is the entry point — these values flow through the `spectre:globals` virtual module to every component (see [03 — Architecture](./03-architecture.md), Pillar 1).

### Step 1.5 — Replace the profile picture

The theme shipped with a stylised purple ghost as the placeholder profile image (`src/assets/pfp.png`, 100×100 px, ~5 KB). We replaced it with a real headshot pulled from Hamza's LinkedIn profile, converted to PNG, normalised to 400×400.

### Step 1.6 — Add a real first post

Empty blog = empty signal of value. The first post needed to exist before the site felt real. Hamza pointed at his own GitHub repo `hamzawork1/Azure-VM-Public-IP-Upgrade-Basic-SKU-to-Standard-SKU` — a real DevOps project documenting how he migrated 300+ Azure VMs from Basic SKU public IPs to Standard SKU.

The repo's README was already well-structured. We converted it into MDX format with proper frontmatter and dropped it at `src/content/posts/azure-vm-public-ip-upgrade-basic-to-standard.mdx`. Date was set to `2025-07-22` to match when the actual work was done (preserving the historical accuracy of the technical content), even though the post was *published on the site* on 2026-05-23.

This pattern — **post date = when the work was done, not when it was published** — was an intentional choice. It tells readers something about when the technical observations were valid, which matters for cloud / DevOps content where API surfaces and best practices change yearly.

---

## Phase 2 — The image strategy

### Step 2.1 — Recognise the per-post image problem

Every post requires a cover image (the schema enforces it). The naive approach is "one custom image per post". This means every new post = "open Figma / Canva / Photoshop / find a stock photo" before you can write. That's friction that kills posting cadence.

We discussed three options:

| Option | Per-post effort | Result |
|---|---|---|
| Per-post custom cover | High (every post needs a design pass) | Most visually unique |
| Reusable tag-based covers | Zero (pick the right tag's banner) | Visually consistent per topic; clear "this is an Azure post" signal |
| External CDN-hosted covers | Same effort as per-post + external service | Repo stays light; overkill for small site |

### Step 2.2 — Pick reusable tag-based covers and build the generator

We chose the middle option. Banners live at `src/content/assets/<tag>-cover.png`. Each tag (azure, devops, kubernetes, terraform, ci-cd, notes, guide) gets one banner; every post tagged `azure` reuses `azure-cover.png`.

**The generator** is `scripts/generate-covers.ps1` — a PowerShell script using .NET's `System.Drawing` to compose:

- A diagonal gradient background (two brand-aligned colours per tag)
- A subtle dot grid overlay
- A soft highlight gradient from the upper right
- A cluster of isometric cubes on the right side (Azure-style aesthetic)
- Corner accent strokes

Each tag has its own `$Palettes` entry in the script:

```powershell
$Palettes = @{
    azure      = @{ Dark1 = @(5,12,35);   Dark2 = @(0,90,180);    Accent = @(120,220,255) }
    devops     = @{ Dark1 = @(10,30,20);  Dark2 = @(20,140,90);   Accent = @(140,255,200) }
    # ...
}
```

Adding a new tag = add a palette entry + run `pwsh scripts/generate-covers.ps1 -Tag <new-tag>`. The banner pops out in seconds.

**Why PowerShell:** Hamza is on Windows; `System.Drawing` is built into .NET; no extra dependencies; reproducible.

### Step 2.3 — Lay out the banner so titles overlay cleanly

A subtle but important design constraint: the post page's title pill is absolute-positioned at the bottom-left of the banner. If the banner has visual content in its bottom-left, the title sits on top of it and looks bad.

The generator puts all the visual interest (cube cluster, corner strokes) on the **right side**. The bottom-left is intentionally an empty zone of the gradient. This way the title overlay sits on a uniform background regardless of which tag's banner is used.

### Step 2.4 — Then drop the title pill background entirely

After looking at the banners with the title overlay, the white pill background (`background: #ffffff`) felt heavy. We removed the pill — title now renders as white text on the banner directly, with a soft dark text-shadow (`0 2px 6px rgba(0, 0, 0, 0.7)`) for legibility. The cleaner look pairs better with the gradient banners.

This is the "design feedback loop" version of a CSS-only change — entirely in `src/styles/article.css`.

---

## Phase 3 — The branch strategy decision

### Step 3.1 — Move off `main`

The repo started with everything on `main`. The first wave of changes was rapid and exploratory — branding tweaks, content swaps, theme edits. Doing those directly on `main` was fine momentarily, but obviously not a model that scales to "actually deployed".

We branched to `start-the-project` and continued the bulk of work there. The plan: once setup felt right, merge to `staging`, then later to `main`.

### Step 3.2 — Set up the formal flow

When it was time to push the work upstream, we formalised:

- `main` → production target (mhamza.space)
- `staging` → pre-production (staging.mhamza.space)
- Topic branches → PR to staging → review → merge

Topic branch naming conventions (`post/`, `feature/`, `fix/`, `docs/`, `ci/`, `chore/`) make the Actions tab readable and the branch list informative.

### Step 3.3 — Squash the history

`main` carried the original Spectre theme commits, plus the bulk-changes commits from `start-the-project`. Hamza wanted the theme commits *gone* from history. Three reasons:

1. The theme's licensing is preserved via the `README.md` credits section — Git history isn't required for attribution.
2. Future contributors / portfolio readers shouldn't have to wade through unrelated theme history to find "Hamza's actual work".
3. The first commit on `main` should describe the project, not be the theme's "initial blog setup".

The mechanic: `git commit-tree` was used to create a brand-new parentless commit pointing at the current working tree, then `git reset --hard <new-commit>` moved staging to it, then both `main` and `staging` were force-pushed.

`start-the-project` was deleted (its purpose was served — everything had landed in staging).

After this operation, both `main` and `staging` started from a single clean commit:

```
* f9098e6 Initial commit: mhamza.space personal site
```

This is one of two times a force-push was used in this project. The other was the second time we needed to clean history — see Phase 4.

### Why this is safe (when done deliberately)

Force-pushing to a long-lived branch is a destructive operation. The reason it was safe here:

- It's a personal repo, no other contributors are tracking the old history.
- The squashed commit's *content* is identical to the previous tip — only the path through history is collapsed.
- The old commits are still in the reflog locally and via GitHub's "Reflog of force-pushed branches" tooling for 90 days, so a panic recovery is possible.

**Don't do this on a shared branch.** Anyone tracking the old history would have to re-clone or do `git fetch && git reset --hard origin/<branch>`.

---

## Phase 4 — pnpm migration + repo hygiene

### Step 4.1 — Discover the mixed lockfiles

At one point an accidental `npm install` produced a `package-lock.json` alongside the existing `pnpm-lock.yaml`. Two lockfiles is two sources of truth, and tools (CI, hosts, fresh contributor laptops) might pick different ones non-deterministically.

The theme had been set up with pnpm from day one (`packageManager: "pnpm@10.27.0"` in `package.json`, `pnpm-workspace.yaml` declaring `package/` as a workspace member). pnpm was the intended manager — the npm leftover was a mistake.

### Step 4.2 — Pick pnpm and commit to it

[ADR 0002](../decisions/0002-pnpm-package-manager.md) records the decision. The short version: pnpm is faster, uses less disk (content-addressable store + hard links), enforces stricter dependency resolution, and has first-class workspace support. The project was already set up for it; we just had to clean up the npm artefacts.

Concrete steps:

1. Delete `node_modules` and `package-lock.json`.
2. Install pnpm globally — first attempt via `corepack prepare pnpm@10.27.0 --activate` hit a Windows permission error (corepack wants to write to `C:\Program Files\nodejs\`, needs admin). Fell back to `npm install -g pnpm@10.27.0` which writes to the per-user npm prefix and doesn't need admin.
3. `pnpm install` — re-creates `node_modules` from `pnpm-lock.yaml`.

### Step 4.3 — Tighten `.gitignore`

A few things were either tracked when they shouldn't have been, or not ignored when they could be:

- `CLAUDE.md` — local mental model for Claude Code sessions, contains project-specific notes. Personal-machine only.
- `.claude/settings.json` and `.claude/settings.local.json` — both contained absolute Windows paths specific to Hamza's machine. The entire `.claude/` folder was added to `.gitignore`.
- `.wrangler/` — Wrangler 4's local cache. No reason to commit.
- `tmp-*/` — generic pattern catching dry-run outdirs and ad-hoc test directories.

The files that were tracked but should have been ignored (`CLAUDE.md`, `.claude/settings.local.json`) were un-tracked via `git rm --cached <file>` so the on-disk file survived but the index was cleared.

### Step 4.4 — Photo, properly

Hamza had a LinkedIn headshot but it downloaded as `.jpg`. The schema doesn't care about extension, but the file was renamed `pfp.jpg`, and `src/assets/pfp.png` was the existing reference. Converted JPG → PNG via PowerShell + `System.Drawing`, ending up with a 400×400 PNG at ~216 KB.

The previous purple-ghost `pfp.png` (5.6 KB) was overwritten.

---

## Phase 5 — Initial documentation set

Before building the pipeline, the project needed enough docs that future-Hamza (or any reader) could understand what was going on.

### Step 5.1 — CHANGELOG

`CHANGELOG.md` in the [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format. Initially had a `[2026-05-23]` section for the bootstrap day, but on 2026-05-25 it became clear that everything was still on `staging` (not released to production), so all entries were moved under `[Unreleased]`. The first real dated section will be cut when the first push to `main` happens.

### Step 5.2 — Architecture Decision Records (ADRs)

Three ADRs in `docs/decisions/`:

- **0001** — Hosting on Cloudflare's edge as a static site (with the reversibility plan in case we ever need SSR).
- **0002** — Pinning pnpm 10.27.0 as the sole package manager.
- **0003** — Adding a fourth axis later — see Phase 6 — but ADR 0003 was originally about doing the deploy from GitHub Actions instead of Cloudflare's native Git integration.

Each ADR follows the standard format: Status, Context, Decision, Alternatives Considered, Consequences, Reversibility. The reversibility section is the most important — every decision has a "how to undo if needed" written down. It's a forcing function for not making irreversible choices casually.

### Step 5.3 — Runbooks

Two operational runbooks in `docs/runbooks/`:

- `deploy-cloudflare-pages.md` — the one-time Cloudflare + secrets setup, custom domains, rollback, troubleshooting. The "Notes during initial setup" section at the bottom is open-ended — every time we hit a real-world surprise, an entry gets added.
- `new-post.md` — the post-by-post workflow. Topic branch → write → push → PR → verify preview → merge → ship. With commands.

ADRs are *why* documents. Runbooks are *how* documents. They reference each other; together they're the operational manual.

### Step 5.4 — First PR

All of the above landed via PR #1 — the first time the formal flow was actually exercised. Topic branch `docs/initial-project-docs`, two logical commits (one for CHANGELOG + ADRs, one for runbooks), open via `gh pr create --base staging`, merged via GitHub UI.

Local cleanup after merge: pull staging, delete the topic branch locally, delete the remote branch. This trio of commands (`git pull`, `git branch -d`, `git push --delete`) became the standard close-out for every subsequent PR.

---

## Phase 6 — CI/CD pipeline

### Step 6.1 — Decide where the deploy logic lives

Cloudflare has two ways to deploy a static site:

1. **Native Git integration.** Cloudflare watches the repo. On push, it builds on its own runners and deploys. Zero pipeline code.
2. **GitHub Actions + Wrangler.** GitHub runs the build. Wrangler uploads the result to Cloudflare's API. Cloudflare just serves.

Option 1 is faster to set up; option 2 has full pipeline control. For Hamza — an Azure DevOps engineer who lives in pipelines daily — option 2 was the better educational fit and the better long-term position (room for future lint / test / scan / deploy-gate steps).

[ADR 0003](../decisions/0003-github-actions-deploy.md) records the decision.

### Step 6.2 — Write the workflow

`.github/workflows/ci-cd.yml` was created with two jobs:

- **build** — runs on every PR + push to main/staging. pnpm + Node setup, lint, build, Pagefind index assertion, artifact upload.
- **deploy** — runs only on push to main/staging. Downloads artifact, runs Wrangler.

Triggers, concurrency control, and GitHub Environments (`production` vs `staging`) for deploy tracking were configured up front.

[05 — CI/CD pipeline](./05-ci-cd-pipeline.md) is a line-by-line walkthrough.

### Step 6.3 — First failure: Node version

The first build job run failed:

```
Node.js v20.20.2 is not supported by Astro!
Please upgrade Node.js to a supported version: ">=22.12.0"
```

Astro 6 requires Node 22+. The workflow had `node-version: 20`. Fix: bump to `node-version: 22` (Node 22 LTS, codename "Jod").

Why we noticed at all: the local environment was Node 24, so locally everything worked. The mismatch only surfaced in CI. This is the case for *always pinning Node version in CI explicitly* — never rely on the host's default, because the host's default changes over time.

### Step 6.4 — Pivot from Pages to Workers (mid-pipeline)

While the user was setting up the Cloudflare side, the dashboard's "Upload assets" flow created a **Worker** (not a Pages project) at `mhamza-space.devops-engineer099.workers.dev`. The URL pattern (`workers/services/view/...`) and the explicit banner "Metrics is unavailable for Workers with only static assets" confirmed it.

In 2024 Cloudflare introduced **Workers with static assets** as the modern successor to Pages. The dashboard now defaults static-asset uploads to Workers; the dedicated Pages "Direct Upload" flow is buried.

Two paths forward:

1. Delete the Worker, manually find the hidden Pages flow, create a Pages project, keep the workflow as-is (`wrangler pages deploy`).
2. Embrace the Worker, update the workflow to use `wrangler deploy` (Workers command), and adapt `wrangler.toml`.

Path 2 was chosen — it aligns with Cloudflare's product direction and the work is minimal:

- Add `wrangler.toml` to the repo with `[assets] directory = "./dist"` and `[env.production]` / `[env.staging]` blocks.
- Change the deploy command from `pages deploy dist --project-name=mhamza-space --branch=<ref>` to `deploy --env <env>`.
- Update ADR 0003 to reflect "Workers + assets" not just "deploy mechanism".
- Update the deploy runbook end-to-end.

### Step 6.5 — Second failure: Wrangler version

The first attempt at the new workflow failed with two errors that turned out to share a root cause:

```
No environment found in configuration with name "staging".
Missing entry-point: The entry-point should be specified via the
command line or the main config field.
```

Cause: `cloudflare/wrangler-action@v3` installs **Wrangler 3.90.0** by default. Wrangler 3 doesn't fully support static-only Workers — it still expects every Worker to have a JavaScript `main` entry-point and can't parse `[env.<name>]` blocks that omit one. The `[assets]` directive is first-class only in Wrangler 4.

Fix: pin `wranglerVersion: "4"` in the action's inputs. The action then installs the latest 4.x line.

**Lesson:** when an action wraps a CLI whose major version matters for a feature, always pin the CLI version explicitly. Don't rely on the action's default.

### Step 6.6 — Third failure: Worker name override

With Wrangler 4 pinned, the deploy succeeded — but the Worker was named **`kb-blogs-staging`** instead of `mhamza-space-staging` declared in `wrangler.toml`'s `[env.staging].name`.

The exact cause was opaque. Hypothesis: Cloudflare resolves the env-block `name` against some pre-existing project context on the account — perhaps the GitHub repo name `kb-blogs` got captured somewhere. The dry-run locally didn't show this issue clearly.

Fix: force the name via the CLI `--name` flag, which overrides config, environment defaults, and any pre-existing project context:

```yaml
command: deploy --env ${{ github.ref_name == 'main' && 'production' || 'staging' }} --name ${{ github.ref_name == 'main' && 'mhamza-space' || 'mhamza-space-staging' }}
```

After the next deploy: Worker correctly named `mhamza-space-staging`.

**Lesson:** when a Cloudflare account has any history with similar-looking names, never trust env-block `name` alone — pin via CLI.

### Step 6.7 — The pipeline pattern, retrospectively

Three iterations to get green. Each one:

1. Tried something
2. Hit a specific failure
3. Read the logs
4. Found the root cause
5. Fixed it via the smallest possible change
6. **Documented the finding in `docs/runbooks/deploy-cloudflare-pages.md` → "Notes during initial setup"**

That last step is the durable value. Anyone (including future-Hamza on a new machine, or a peer who clones the repo) can read the Notes section and skip the three iterations.

---

## Phase 7 — Staging goes live

### Step 7.1 — First successful deploy

After the three iterations, the deploy job uploaded 37 files in 1.67 seconds and posted the URL:

```
https://mhamza-space-staging.devops-engineer099.workers.dev
```

`curl -I` returned 200. The home page rendered. Search worked (Pagefind index inside `dist/pagefind/` had been generated by `postbuild` and shipped as part of the artifact).

### Step 7.2 — Attach the custom domain

`mhamza.space` was already on Cloudflare DNS — a prerequisite for Workers' "Custom Domain" feature. In the dashboard:

1. `mhamza-space-staging` Worker → Domains tab → **+ Add** → **Custom Domain**.
2. Entered `staging.mhamza.space`. Cloudflare detected the zone, auto-created the DNS record, started SSL provisioning.
3. ~1 minute later: status went to Active. `https://staging.mhamza.space` started serving the same content as the `.workers.dev` URL.

### Step 7.3 — Disable the default `.workers.dev` URL

After a custom domain is attached, the default `.workers.dev` URL stays active. For a staging site this means two URLs serve the same content — a duplicate-content SEO concern, and a privacy concern (anyone can guess `mhamza-space-staging.devops-engineer099.workers.dev`).

The fix is a toggle in the same Domains tab — disable the `.workers.dev` row. After disable, only `staging.mhamza.space` reaches the Worker.

For production, we'll repeat the same pattern when the production Worker is provisioned: attach `mhamza.space` + `www.mhamza.space`, disable the `.workers.dev` URL.

---

## Phase 8 — An accidental PR, closed properly

While clicking around the GitHub UI, a "New pull request" button was hit at the wrong time and opened PR #4 from `staging` → `main` titled simply "Staging". This wasn't intended — production deploys are a deliberate event, not a casual click.

The PR was closed without merging via `gh pr close 4 --comment "..."`. `main` stayed untouched. No deploy was triggered. The lesson is small but worth recording: **the production deploy PR is always created by the person, not by accidental UI clicks**.

---

## Phase 9 — Where we are today (end of 2026-05-25)

Status:

- **Staging** is live at https://staging.mhamza.space. Custom domain, SSL, `.workers.dev` disabled. CI/CD running clean.
- **Production** is not yet deployed. `main` still sits at the bootstrap commit; the Worker `mhamza-space` still serves the placeholder content from the user's original "upload README" gesture.
- All documents (README, CHANGELOG, ADRs, runbooks, this learning kit) are in `staging`.

What's left to make production live (in order):

1. **PR `staging` → `main`** when ready. Merge triggers a push to `main`, which triggers the deploy job, which creates / replaces Worker `mhamza-space` with the real site.
2. **Custom domain on production** — attach `mhamza.space` + `www.mhamza.space` to the `mhamza-space` Worker. Disable that Worker's `.workers.dev` URL.
3. **Delete the orphan `kb-blogs-staging` Worker** from the Cloudflare dashboard (it was created during Phase 6.6 before the `--name` fix; nothing routes to it anymore).

That's it. After those three, the site is end-to-end live and the next 100 commits are content, not infrastructure.

---

## Reflective summary

Looking back over the journey, a few patterns stand out:

1. **Every choice that turned out to be the right one was the choice that left a paper trail.** The ADRs, runbook Notes, and conventional commit messages mean a year from now you can still tell *why* — not just *what*.

2. **Every "feature failure" was actually a documentation success.** The Node 22, Wrangler 4, and `--name` flag findings would all bite anyone setting up a similar project from scratch. They're written down. They won't bite us again.

3. **The branch flow felt heavy at first, became invisible by PR #3.** Forcing every change through a topic branch + PR seemed like overhead for solo work. By the time we'd run through the iteration cycle four times, the muscle memory was set and the cost was zero.

4. **Static + edge is the right default for content sites.** No server, no database, no auth, no scaling concerns. The "boring" choice that scales fine for years.

5. **The platform direction matters.** We pivoted from Pages to Workers mid-pipeline because Cloudflare's UI was telling us where the puck was going. Riding the platform's direction is cheaper than fighting it.

---

Next: [05 — CI/CD pipeline](./05-ci-cd-pipeline.md)
