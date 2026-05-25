# 09 — Decisions

A narrative version of every architecture decision made in this project. The structured per-decision files live in `docs/decisions/` — each one follows the standard ADR format. This file is a *reader's bridge*: it tells the story of the decisions, the order they were made in, and how they interlock.

Read this when:

- Someone asks "why didn't you just use X?"
- You're considering reversing a decision and want the full context.
- You're documenting a similar project elsewhere and want to harvest the reasoning.

For depth on any single decision, click through to the ADR.

---

## The four big decisions, in order

```
1. Host the site as a static deploy on Cloudflare's edge.     (ADR 0001)
                          ↓
2. Use pnpm 10.27 as the sole package manager.                (ADR 0002)
                          ↓
3. Deploy via GitHub Actions + Wrangler — not Cloudflare's    (ADR 0003)
   native Git integration — and target Workers (with static
   assets) instead of Pages.
                          ↓
4. (Operational, not an ADR) Strict topic-branch + PR flow,
   even for solo work.
```

Each downstream decision depends on the one above it but isn't strictly required by it. You could have static + Pages + native deploy + direct-commit-to-main. The combination we ended up with is **internally consistent** because each choice reinforces the others.

---

## Decision 1 — Static deploy on Cloudflare's edge

### What we chose
The site is built as static HTML/CSS/JS at build time and served from Cloudflare's edge — no server-side rendering, no databases, no per-request code, no Node runtime in production.

### Why

The site does these things:
- Markdown content authored in Git.
- A small home page with profile + sidebar + recent-posts preview.
- A blog list page.
- Individual post pages.
- Optional Giscus comments (a JS embed, not a server thing).
- Search via Pagefind — a build-time static index.

None of those require server-side rendering. They don't even *benefit* from it. Pre-rendering every page once at build time gives us:

- **Speed.** Cloudflare's CDN caches the bytes globally. First-byte time is the network round-trip; not "wait for Node to render and respond".
- **Cost.** Free tier on Cloudflare's edge is essentially unlimited for a site of this scale.
- **Reliability.** No server means no server-side bugs, no memory leaks, no scaling. The site is up as long as Cloudflare is up.
- **Security.** No attack surface. No code is executing in response to user requests. The runtime is just an asset server.

### Alternatives we ruled out

**Vercel.** Best-in-class DX for Next.js — but we're on Astro, and Next.js's strengths don't apply. Vercel's bandwidth limits on the free tier are tighter than Cloudflare's. We'd be paying a small ongoing cost or eventually migrating.

**Netlify.** Mature, generous free tier. But the Cloudflare ecosystem we'd want to grow into (R2 object storage, Workers, Images, Stream) is on Cloudflare. Picking Netlify would mean two providers.

**GitHub Pages.** Free, integrates with the repo natively. But no PR-level preview deploys, no custom-domain SSL management as smooth as Cloudflare's, no edge-level controls. Acceptable for a tiny static site; less so for one that might grow features.

**Self-hosted VPS with Nginx.** Maximum control. But ongoing OS patching, TLS rotation, monitoring. Disproportionate to a personal blog.

### What would make us reverse this

If we ever needed:
- Authenticated content for a subset of pages
- Dynamic OG images per visitor
- Form submissions that don't go through a third-party service
- Heavy personalisation

Then a partial SSR layer would be justified. Cloudflare itself supports SSR for Workers — we could flip `output: "server"` in `astro.config.ts` and add the `@astrojs/cloudflare` adapter without changing host. Reversibility is straightforward; we just haven't needed it.

### Where it's recorded
[`docs/decisions/0001-static-cloudflare-pages.md`](../decisions/0001-static-cloudflare-pages.md)

---

## Decision 2 — pnpm as the sole package manager

### What we chose

pnpm 10.27.0 (pinned via `packageManager` field in `package.json`). `pnpm-lock.yaml` is committed; `package-lock.json` and `yarn.lock` are not allowed in the repo.

### Why

The repo is a pnpm workspace by design. Two packages:

- The root — the Astro site.
- `package/` — the customised Spectre integration, a sibling workspace member that publishes the local virtual-module plugin.

pnpm's workspace support is first-class — `pnpm install` from the root resolves both packages correctly without extra config. npm and yarn can do workspaces too, but with more setup and with weaker isolation guarantees.

Beyond workspaces:

- **Strict dependency resolution.** A file can only import packages that are *directly* declared in `package.json`. No accidental reliance on transitive deps. This catches "I forgot to add lodash but it was transitively pulled in by some other dep, then that dep dropped lodash and my code broke" — a class of bug npm allows.
- **Disk efficiency.** Content-addressable global store + hard links. Across multiple Astro projects on a developer's machine, this saves gigabytes.
- **Speed.** Empirically ~2× faster than npm for our install. Not life-changing, but adds up.

### Alternatives we ruled out

**npm.** The default. Familiar. Workspaces work but aren't as ergonomic. No strict dependency resolution. Bigger `node_modules`.

**yarn (Classic or Berry).** Berry's Plug'n'Play is interesting, but requires per-tool support (Astro, Biome, Pagefind all need to understand PnP). Classic yarn has no PnP advantage over npm. Either way, no clear edge over pnpm here.

**bun.** Very fast install. Native TS/JSX runtime. But Astro is npm/pnpm-first; bun's package-manager mode is newer and less battle-tested in CI on Cloudflare Pages-style flows. Maybe revisit in 2027.

### What would make us reverse this

If we wanted to:
- Eliminate the `package/` workspace package and inline the Spectre integration into the root (loss of separation of concerns).
- Move to a different language ecosystem entirely.

Reversibility is non-trivial — see ADR 0002's reversibility section for the exact steps.

### Where it's recorded
[`docs/decisions/0002-pnpm-package-manager.md`](../decisions/0002-pnpm-package-manager.md)

---

## Decision 3 — GitHub Actions deploy, targeting Workers (not Pages)

This was actually two decisions made together. The ADR captures them on the same axis because they're tightly entangled.

### Decision 3a — Deploy from GitHub Actions, not Cloudflare's native Git integration

#### What we chose

`.github/workflows/ci-cd.yml` runs the build on GitHub-hosted runners and uses Wrangler to upload the result to Cloudflare. Cloudflare is *only* the host — it doesn't watch the repo or build anything.

#### Why

The user is an Azure DevOps engineer. Pipeline-as-code is the operating mental model. Every deploy should be an auditable Git workflow with:

- Visible steps in the GitHub Actions UI
- The ability to insert future checks (type-check, security scan, Lighthouse, etc.) without re-architecting
- Failure debugging inside the same UI you use for the repo
- Secrets and protections that live with the repo

Cloudflare's native Git integration does all the build/deploy in their environment. It works, but you have less visibility, fewer customisation hooks, and a "two systems to look at when something's wrong" topology.

#### Cost

CI minutes are consumed on every push and PR. Free tier is 2,000 min/month for private repos. Our pipeline takes ~2 min per run. We have plenty of headroom.

#### Alternatives we ruled out

**Cloudflare Pages + native Git.** Zero-config, fastest setup. But less control and the platform is on a maintenance-only track relative to Workers + assets.

**Custom self-hosted runner.** Unlimited minutes, full control of environment. Overhead of maintaining the runner. Not justified for the current scale; revisit if CI usage outgrows the free tier.

#### Where it's recorded
[`docs/decisions/0003-github-actions-deploy.md`](../decisions/0003-github-actions-deploy.md)

---

### Decision 3b — Cloudflare Workers (with static assets), not Cloudflare Pages

#### What we chose

The site is deployed as a Cloudflare **Worker** with the `[assets]` directive pointing at `./dist/`. Not a Cloudflare Pages project.

#### Why

In 2024 Cloudflare introduced "Workers with static assets" as the modern successor to Pages. The dashboard now defaults static-asset uploads to Workers; Pages' "Direct Upload" flow is hidden behind specific URLs. Cloudflare's product roadmap statements have made it clear they're consolidating around Workers — Pages enters a maintenance track.

We discovered this mid-setup. The user uploaded a README via the Cloudflare dashboard to create the initial project; the result was a Worker, not a Pages project. We had two choices:

1. Backtrack — delete the Worker, find the hidden Pages flow, create a Pages project, keep the workflow as originally written (`wrangler pages deploy`).
2. Adapt — change the workflow's deploy command (`wrangler deploy --env <env>`), add a `wrangler.toml` declaring the environments, and lean into Workers.

We chose adapt. The reasoning: align with the platform's direction, not against it. Workers + assets is where Cloudflare's future investment is going. Pages will keep working but won't get new features.

#### Cost

A bit of additional learning curve — Workers' config syntax (`wrangler.toml`) is slightly different from Pages'. We hit two pipeline issues that wouldn't have existed with Pages:

- Wrangler 3 doesn't fully support the `[assets]` directive (had to pin Wrangler 4).
- Cloudflare's resolution of `[env.<name>].name` was overridden by pre-existing project context (had to pass `--name` explicitly).

Both are documented and one-line fixes. Worth it.

#### Alternatives we ruled out

**Pages + GitHub Actions.** Possible via `wrangler pages deploy` or the `cloudflare/pages-action@v1`. The latter is deprecated. The former still works but you're riding Pages on its slow descent.

**Pages + native Git.** Easiest to set up. Cloudflare-owned tooling improvements stop here.

#### Where it's recorded
Same as 3a: [`docs/decisions/0003-github-actions-deploy.md`](../decisions/0003-github-actions-deploy.md) — the ADR covers both axes.

---

## Decision 4 — Strict topic-branch + PR flow (operational, not an ADR)

### What we chose

Every change to the codebase goes through this sequence:

1. Branch off `staging` with a typed name (`post/`, `feature/`, `fix/`, `docs/`, `ci/`, `chore/`).
2. Make changes. Commit incrementally with conventional messages.
3. Push the branch. Open a PR to `staging`. CI runs build + lint.
4. Merge the PR (after review, even if review is "the author rereading their own diff").
5. Verify on `staging.mhamza.space`.
6. When ready, open a `staging → main` PR for production deploy. Merge it deliberately.

No commits ever land directly on `main` or `staging` without a PR. No exceptions.

### Why

This is overhead for solo work. It pays off because:

- **CI runs on every change.** Build broken? You know before you merge.
- **PR descriptions are self-documenting.** Six months from now, "why did I change this?" has an answer in the PR body.
- **The merge commit is a natural rollback point.** "Revert this merge" is one click in GitHub.
- **Production deploys are deliberate.** You can't accidentally push to main from a topic branch.
- **The workflow file's `pull_request` + `push` triggers fire in the right order.** Building on PR catches issues; deploying on push to main/staging happens after the merge commit lands.

The friction is the point. One extra step before code goes live is one chance to catch a mistake. Solo or not.

### What would make us reverse this

If contribution velocity ever felt artificially throttled by the PR step. For a personal blog, the writing speed is the rate-limit anyway, so the friction is invisible. If the site grew into a team-edited multi-author publication with many contributors per day, we might consider auto-merging trivial PRs. Today, no.

### Where it's recorded

Documented in `README.md` (high-level), `docs/learning/01-overview.md` (the rationale), and `docs/runbooks/new-post.md` (the per-change steps). Not its own ADR because it's a workflow choice, not an architecture choice.

---

## Decision 5 — Tag-based reusable cover banners (operational, not an ADR)

### What we chose

Each post must have a cover image. Instead of generating a unique banner per post, the project ships **one banner per tag** (azure, devops, kubernetes, terraform, ci-cd, notes, guide). A post tagged `azure` reuses `azure-cover.png`. New tag = new palette entry in `scripts/generate-covers.ps1` + one regeneration.

### Why

Per-post bespoke banners create friction every time you publish:

- "Open Figma, design something, export PNG."
- 30 minutes per post that should be 0.

The cost is that posts on the same topic share a banner — but on a tech blog where the value is the content, banner uniqueness adds nothing.

Visual consistency per topic is actually a *feature*. A reader scrolling the blog list immediately sees that all the Azure posts have the cyan-tinted banner; the visual language reinforces the categorisation.

### Cost

If we ever want a special banner for a flagship post, we override at the post's frontmatter — just point `image:` at a different file. The default is "use the tag's banner", not "must use the tag's banner".

Storage: ~1.3 MB total for all seven banners. Negligible.

### Alternatives we ruled out

**Per-post unique banners.** Real cost. Not justified.

**External CDN (Cloudflare Images, R2 + custom subdomain).** Useful if the asset folder grew to many tens of MB. We're nowhere near. Reversible later: change the schema to accept URLs, host the banners externally, update each post's `image:`.

### Where it's recorded

`README.md` "Image strategy" section + `docs/learning/06-daily-workflows.md` "Add a new tag" section. Not its own ADR because it's a content-ops choice.

---

## The pattern across all five decisions

If you look at the five decisions side-by-side, they share a structure:

1. **Pick the boring, scalable default.** Static. pnpm. Workers. PR-driven. Reusable banners.
2. **Lean into the platform direction.** Don't fight Cloudflare's Workers push. Don't pretend npm is going to add strict resolution. Don't pretend Pages is the future.
3. **Pay the friction cost upfront, harvest the simplicity forever after.** PR flow feels heavy on day one; invisible by day fourteen. Setting up the pipeline takes an afternoon; it runs itself for years.
4. **Reversibility matters more than the initial choice.** Each ADR has a "what would make us reverse this" section. Knowing the exit ramp lowers the stakes of any decision.
5. **Document the why, not just the what.** The CHANGELOG records what shipped. ADRs record why. Runbooks record how. This kit records the story. Future-you (or any reader) can navigate from any of those four entry points to the others.

That's the underlying philosophy. Apply it to every new decision you make on this project, and you'll end up with a system that scales without rewriting.

---

## What's *not* a decision (worth noting)

Some choices look like decisions but aren't, because there was only one sensible option:

- **Astro as the framework.** The theme is built for Astro; "use a different framework" would mean throwing away the theme entirely.
- **TypeScript over JavaScript.** Astro speaks both. TypeScript is the obvious choice for any project that intends to be readable in a year.
- **MDX for posts.** Plain Markdown works but loses the ability to embed components. MDX is a strict superset — costs nothing, opens future possibilities.
- **Biome for lint + format.** Single-tool replacement for ESLint + Prettier. Modern, fast, recommended by Astro.
- **`git` for source control.** Not 1995.

These aren't "decisions" in the ADR sense — they're foundation. If we listed every such choice we'd have 30 ADRs and they'd dilute the real ones.

---

## What's *not yet* a decision (open questions)

Things we haven't decided because we haven't needed to:

- **What happens at 100 posts?** The home page shows recent posts via `getCollection`. At 100 posts the build might slow noticeably (image processing). Will revisit when we hit ~30.
- **Should we add a tags / archive page?** Currently posts can be tagged but there's no `/tags/<tag>` page listing posts by tag. Easy to add; not done because nothing requires it yet.
- **Should we enable Giscus comments?** Block is wired up but disabled. Will revisit when posts start getting external traffic and feedback becomes valuable.
- **Should we add an RSS feed?** Astro has a built-in integration. Easy to add. Will revisit when we have a subscriber-style audience.
- **Should we add light-mode support?** Theme is dark-only. Adding light mode is a multi-file CSS change; not trivial but tractable. No request from the user yet.

When any of these moves from "haven't needed" to "have a real reason", we'll add an ADR. Until then, they're just notes.

---

## How to add a new decision to this kit

When you make a non-trivial architectural choice in the future:

1. **Write the ADR first** at `docs/decisions/<NNNN>-<short-name>.md` using the standard format (see ADRs 0001-0003 as templates).
2. **Add a section to this file** summarising the decision in the narrative style above. It should answer "what we chose, why, alternatives, reversibility" in flowing prose.
3. **Update `docs/learning/index.md`** if the decision changes the recommended reading paths.
4. **Update `CHANGELOG.md`** with an `### Decisions` sub-entry under the next release.

Decisions are most useful when they're recorded *immediately* — before the context fades. Don't accumulate a backlog of "I'll write the ADR later".

---

That's the end of the learning kit. You've got:

- The site's tech stack and operating model (01-02-03).
- The story of how it was built and why (04-09).
- The pipeline that ships changes (05).
- The day-to-day workflow for posts and content (06).
- The map of "where to change what" (07).
- The debugging guide for when things break (08).

From here on out, you should not need to touch infrastructure. Just write.

Good luck.
