# 02 — Tooling primer

This file is a fast briefing on every tool the project depends on. The goal is to give you just enough mental model that the rest of the kit makes sense. Each section links to the canonical docs for depth.

If you're already comfortable with a tool, skim and move on.

---

## Astro

**What it is:** A static-site framework. You write pages in `.astro`, `.md`, or `.mdx`; Astro compiles them to plain HTML/CSS/JS at build time. Zero JavaScript ships to the browser by default — only the markup and styles needed for the page.

**Why this project uses it:** Content-driven sites that ship as static HTML are exactly Astro's sweet spot. Compared to Next.js it's leaner. Compared to Eleventy it has better TypeScript and component support.

**Mental model:**

```
src/
├── pages/         <- file = route. blog.astro -> /blog
├── layouts/       <- shared shells used by pages
├── components/    <- reusable .astro pieces
├── content/       <- markdown / mdx / json content
├── content.config.ts  <- schemas (Zod) for everything in src/content/
└── styles/        <- global CSS
```

Key concepts:

- **File-based routing.** `src/pages/blog.astro` becomes `/blog`. `src/pages/blog/[post].astro` becomes `/blog/<slug>` and uses `getStaticPaths()` to enumerate the slugs at build time.
- **Content collections.** Anything inside `src/content/` is loaded as a collection. Schemas in `src/content.config.ts` define shape, types, and validation. A blog post with an unknown tag fails the build — caught at compile time, not run time.
- **MDX.** Markdown plus the ability to embed components. We use it for posts so that future posts can include charts, callouts, etc. without changing the schema.
- **Frontmatter.** YAML at the top of each `.md` / `.mdx` — title, description, image, dates, tags. Schema-validated.
- **Image optimisation.** Astro has built-in image processing (uses Sharp). We point `image:` to a relative path in frontmatter and it gets optimised at build time.
- **Output target.** `output: "static"` in `astro.config.ts` means everything is pre-built HTML. There is no Node adapter; there's no SSR.

**Where to learn more:** <https://docs.astro.build>

---

## Spectre theme + the local integration

**What it is:** Spectre is a published Astro theme — terminal-inspired, dark, fast. We don't install it as an npm dependency. Instead, the theme's source has been **forked into this repo's `package/` workspace package** and customised.

**Why a workspace package and not a folder copy:** the integration exposes a Vite virtual module `spectre:globals`. The integration code needs a build step (TypeScript → JS). Keeping it as a workspace package lets pnpm + Astro + Vite handle that build naturally.

**What "virtual module" means:** when any file in `src/` does `import { name, openGraph, giscus } from "spectre:globals"`, Vite intercepts that import path (there is no real file `spectre:globals` on disk) and returns whatever the integration emits. The integration's job is to take the options passed to `spectre({ ... })` in `astro.config.ts` and turn them into JS exports.

**To change a config that affects the whole site** (like the site title, OG meta, theme colour, Giscus settings), you edit `astro.config.ts` — not any file in `src/`. The change flows through the virtual module to every component.

**Where to learn more:** read `package/src/integration.ts`. It's ~200 lines and fully readable.

---

## Cloudflare Workers + static assets

**What it is:** Cloudflare's edge compute platform. A "Worker" is a small piece of JavaScript that runs at every Cloudflare data centre (300+ globally). In 2024 Cloudflare added the ability to attach **static assets** to a Worker — meaning you can ship a folder of pre-built HTML/CSS/JS and have the Worker serve them.

For a static site like ours, the Worker has **no custom code at all**. It just says "serve from `./dist`, fall back to `404.html` if no match". The runtime piece is just the routing of HTTP requests to assets.

**Why this and not Cloudflare Pages?** Both work for static sites. Pages is the older product. Cloudflare's product roadmap in 2024+ has been to **converge Pages onto Workers** — the Pages "Direct Upload" flow is now hidden in the dashboard, and "Workers with static assets" is what the UI defaults you to. We followed the platform direction. Details in [ADR 0003](../decisions/0003-github-actions-deploy.md).

**Two-environment setup:**

- Worker `mhamza-space` → serves `mhamza.space` (production)
- Worker `mhamza-space-staging` → serves `staging.mhamza.space` (staging)

They are completely separate Workers, with separate deployments and separate version histories. Rolling back staging doesn't affect production and vice versa.

**Custom domains:** You attach a hostname (e.g. `staging.mhamza.space`) to a Worker via the dashboard. Cloudflare auto-creates a DNS record in the zone and provisions an SSL cert. After that the Worker also has a default `.workers.dev` URL — we disable that so only the custom domain reaches the Worker.

**Where to learn more:** <https://developers.cloudflare.com/workers/static-assets/>

---

## Wrangler CLI

**What it is:** Cloudflare's official CLI for deploying and managing Workers. We use Wrangler 4 because static-asset Workers depend on the `[assets]` config block, which Wrangler 3 doesn't fully support.

**How it's invoked here:** never locally during normal development. It only runs inside the CI deploy job, via the `cloudflare/wrangler-action@v3` GitHub Action, which is a wrapper that installs Wrangler and runs a command for us.

You *can* run it locally for one-off operations (e.g. listing your Workers, doing a dry-run). To do that you need `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` available as env vars locally.

**Config file:** `wrangler.toml` at the repo root declares both environments:

```toml
name = "mhamza-space"
compatibility_date = "2025-05-25"

[assets]
directory = "./dist"
not_found_handling = "404-page"

[env.production]
name = "mhamza-space"

[env.staging]
name = "mhamza-space-staging"
```

The CI deploy step runs `wrangler deploy --env <env> --name <name>`. The `--name` is passed explicitly because Cloudflare's resolution of `[env.<name>].name` was found to be overridden by pre-existing project context on the account.

**Where to learn more:** <https://developers.cloudflare.com/workers/wrangler/>

---

## pnpm + the workspace setup

**What it is:** A package manager that replaces `npm` or `yarn`. It uses a content-addressable global store on disk, so identical files across all your projects exist exactly once and are hard-linked into each project's `node_modules`. Faster, much smaller on disk, strict about which dependencies a file is "allowed" to import.

**Why this repo uses pnpm:**

1. **Workspaces.** This repo has two packages — the root (the site) and `package/` (the customised Spectre integration). pnpm's workspace support is first-class. You can run `pnpm <cmd>` from the root and it understands both.
2. **Strict resolution.** A file in your code can only import a dependency that's *directly* declared. No accidental reliance on a transitive dependency that might disappear in a minor bump.
3. **Disk efficiency.** Especially valuable if you have many Astro / TypeScript projects locally.
4. **`packageManager` field.** `package.json` declares `"packageManager": "pnpm@10.27.0"`. With `corepack enable`, this tells Node which pnpm version to use automatically.

**Day-to-day commands:**

```powershell
pnpm install                     # install everything from pnpm-lock.yaml
pnpm install --frozen-lockfile   # what CI uses; fails if lockfile is stale
pnpm dev                         # run the "dev" script in package.json
pnpm <script>                    # run any package.json script
pnpm add <pkg>                   # add a runtime dependency
pnpm add -D <pkg>                # add a dev dependency
pnpm dlx <pkg>                   # one-off run without adding (like npx)
```

**Lockfile rule:** Commit `pnpm-lock.yaml`. Don't commit `package-lock.json` or `yarn.lock`. If one of those appears, delete it.

**Where to learn more:** <https://pnpm.io/>

---

## Git + the branch flow

**Assumed knowledge:** you can `git add`, `commit`, `push`, `pull`, switch branches, and understand merge vs rebase.

**What's specific to this project:**

- **Two long-lived branches.** `main` and `staging`. Everything else is short-lived.
- **Topic-branch names matter.** They show up in PR titles, in the branch list, and (most importantly) in the workflow run filter on the Actions tab. Use `post/`, `feature/`, `fix/`, `docs/`, `ci/`, or `chore/` prefixes.
- **Conventional commit messages.** Format: `type(scope): short summary`. `type` is one of `feat`, `fix`, `docs`, `chore`, `ci`, `post`. Optional `scope` is the area touched. The body explains why, not what.
- **History is squashed at the root.** The project's git history was rewritten on 2026-05-25 — the original theme commits are gone, and `main` and `staging` both start from a single clean commit. This means anyone who cloned the repo before that date is out of sync; they have to re-clone.
- **No force-push to `main` or `staging`.** Ever. If something needs reverting, do it through a normal commit + PR.
- **Always merge through a PR**, even solo. The CI runs on every PR, which is the cheap safety net.

**Useful one-liners:**

```powershell
# Create topic branch off the current state of staging
git checkout staging
git pull --ff-only origin staging
git checkout -b post/my-new-post

# Push the topic branch and open a PR in one step
git push -u origin post/my-new-post
gh pr create --base staging --head post/my-new-post

# After merge, clean up locally
git checkout staging
git pull --ff-only origin staging
git branch -d post/my-new-post
git push origin --delete post/my-new-post
```

**Where to learn more:** the Pro Git book is free at <https://git-scm.com/book>.

---

## GitHub Actions

**What it is:** GitHub's CI/CD platform, built into every repo. Workflows are YAML files in `.github/workflows/`. Each workflow has one or more *jobs*; each job has *steps*; each step is either a shell command or a pre-built *action*.

**Free tier:** Public repos get unlimited GitHub-hosted runner minutes. Private repos get 2,000 minutes/month on the Free plan. Our pipeline takes ~2 minutes per run; well under the cap.

**Core concepts as used here:**

- **Trigger.** `on: { push, pull_request }` — when does the workflow run?
- **Job.** A grouped sequence of steps that runs on a fresh VM (`runs-on: ubuntu-latest`).
- **Step.** Either a `run: <shell command>` or a `uses: <action>` (a reusable action from GitHub Marketplace, e.g. `actions/checkout@v4`).
- **Secret.** Encrypted key/value stored in repo settings. Available to steps as `${{ secrets.NAME }}`. Two are used here: `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`.
- **Environment.** A logical deploy target. We have `production` and `staging`. They show up on the repo's "Environments" tab with the deploy URL.
- **Artifact.** A folder uploaded by one job and downloaded by a later job — how we move the built `dist/` from `build` to `deploy` without rebuilding.
- **`needs:`.** Declares a job dependency. Our `deploy` job has `needs: build`.
- **`if:`.** Conditional execution. Our `deploy` job has `if: github.event_name == 'push'` so PRs don't deploy.

**Two execution paths through `ci-cd.yml`:**

```
PR opened/updated:
    build job → success → PR check turns green ✅
    (deploy job is skipped — it has if: event == push)

Push to main or staging (which happens when a PR is merged):
    build job → success
        ↓ artifact: site-dist
    deploy job → wrangler deploy --env <env>
        ↓
    new version is live at the corresponding URL
```

**Where to learn more:** <https://docs.github.com/actions>

---

## How it all clicks together

Here's the same diagram from `01-overview.md`, now with the tool names mapped onto the boxes you've just read about:

```
                You (writes MDX, commits, opens PR)
                          │
                          │  git push → GitHub
                          v
                  ┌────────────────────┐
                  │  hamzawork1/kb-blogs│
                  │  (Git + GitHub)    │
                  └────────────────────┘
                          │
                          │  push event → workflow trigger
                          v
                  ┌────────────────────┐
                  │  GitHub Actions    │
                  │  ci-cd.yml         │
                  │   ┌────────────┐   │
                  │   │ build job  │   │  pnpm install --frozen-lockfile
                  │   │            │   │  pnpm lint  (Biome)
                  │   │            │   │  pnpm build (Astro + Pagefind)
                  │   │            │   │  upload artifact: site-dist
                  │   └────────────┘   │
                  │         │          │
                  │         v          │
                  │   ┌────────────┐   │
                  │   │ deploy job │   │  download artifact
                  │   │            │   │  wrangler deploy --env <env> --name <name>
                  │   └────────────┘   │
                  └────────────────────┘
                          │
                          │  Wrangler 4 → Cloudflare API
                          v
                  ┌────────────────────┐
                  │  Cloudflare Worker │
                  │  (static assets)   │
                  │  serves dist/      │
                  └────────────────────┘
                          │
                          │  HTTPS over Cloudflare's global CDN
                          v
                    Your readers
```

Every box on this diagram has a single responsibility. That's the whole point of the architecture.

---

Next: [03 — Architecture](./03-architecture.md)
