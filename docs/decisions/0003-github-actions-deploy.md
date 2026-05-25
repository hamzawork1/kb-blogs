# ADR 0003 — Deploy via GitHub Actions to a Cloudflare Worker (static assets)

- **Status:** Accepted
- **Date:** 2026-05-25
- **Deciders:** Muhammad Hamza
- **Supersedes parts of:** [ADR 0001](./0001-static-cloudflare-pages.md) (the
  host is still Cloudflare's edge; the **product** changes from Pages to
  Workers-with-Static-Assets, and the **deploy mechanism** changes from
  native Git integration to GitHub Actions + Wrangler).

## Context

Two intertwined decisions are captured here.

### 1. Cloudflare Workers (with static assets) vs Cloudflare Pages

In 2024 Cloudflare introduced **Workers with static assets** as the modern
replacement for Pages. The UI now defaults users to creating Workers when
they upload static files; the dedicated Pages "Direct Upload" flow is
hidden behind specific URLs. Pages remains supported but is on a
maintenance-only track.

For this project, the initial dashboard interaction landed us with a
Worker named `mhamza-space` serving on `mhamza-space.devops-engineer099.workers.dev`.
Rather than backtrack and force a Pages project, we lean into the
platform direction.

### 2. Native Git deploy vs GitHub Actions

Cloudflare can deploy either way:

1. **Native Git integration** — Cloudflare watches the repo, builds on its
   own builders, deploys on every push. Zero pipeline code.
2. **GitHub Actions + Wrangler** — we build inside GitHub Actions and push
   the pre-built `dist/` to Cloudflare via Wrangler. Cloudflare only serves.

The user is an Azure DevOps engineer. Pipeline-as-code is the operating
mental model — every deploy should be an auditable Git workflow with
visible steps, gates, and the option to insert checks before shipping.

## Decision

Drive deploys from **GitHub Actions** using the `cloudflare/wrangler-action@v3`
action. Cloudflare hosts the site as a **Worker with static assets**, with
two named environments declared in `wrangler.toml`:

| Environment | Worker name | Triggered by branch | Public URL (initial) |
|---|---|---|---|
| `production` | `mhamza-space` | `main` | mhamza.space (after custom domain wired) |
| `staging` | `mhamza-space-staging` | `staging` | staging.mhamza.space (after custom domain wired) |

The GitHub Actions workflow has two jobs:

| Job | Trigger | What it does |
|---|---|---|
| **build** | every PR + every push to `main`/`staging` | `pnpm install --frozen-lockfile`, `pnpm lint`, `pnpm build`, verify Pagefind index, upload `dist/` as artifact |
| **deploy** | only push to `main` or `staging` (not PRs) | downloads the build artifact, runs `wrangler deploy --env <env>` where the env is selected based on the branch |

The Worker itself runs no application code — it's a "static-only" Worker.
`wrangler.toml`'s `[assets]` directive points at `./dist`, and Cloudflare
serves the built files directly from the edge.

## Alternatives considered

| Option | Pros | Cons | Verdict |
|---|---|---|---|
| **Workers with static assets + GitHub Actions + Wrangler** (chosen) | Cloudflare's current direction; full pipeline control; one tool for build, lint, deploy; easy to add future checks (type-check, scans, Slack-notify); matches the user's DevOps muscle memory; failures debuggable in the GH UI; secrets live with the repo. | One more config file (`wrangler.toml`); CI minutes consumed (well under free tier). | ✅ Selected |
| Cloudflare Pages + native Git integration | Zero pipeline code; preview URL on every PR for free; per-branch preview deploys without env config. | Pages is on a maintenance-only track relative to Workers + assets; build runs in Cloudflare's environment with limited visibility; can't gate on extra checks without reintroducing GH Actions anyway. | Rejected |
| Cloudflare Pages + GitHub Actions (`pages-action@v1` / `wrangler pages deploy`) | Pipeline control + Pages's per-branch preview semantics. | Still riding the Pages product, which Cloudflare is steering users away from; `pages-action@v1` is deprecated. | Rejected |

## Consequences

- The repo needs two secrets on the GitHub side:
  - `CLOUDFLARE_API_TOKEN` — scope `Account → Workers Scripts → Edit`
    (plus `Account → Account Settings → Read`).
  - `CLOUDFLARE_ACCOUNT_ID` — visible in the Cloudflare dashboard's right
    sidebar, also embedded in dashboard URLs.
- `wrangler.toml` at the repo root declares both environments
  (`production`, `staging`) and the `[assets]` configuration. Wrangler
  creates / updates the two Workers (`mhamza-space`, `mhamza-space-staging`)
  on the first deploy to each branch.
- The initial Worker created by uploading a README is fine — the first
  `wrangler deploy --env production` from CI will overwrite it with the
  built site.
- PR previews are not automatic with this setup. Topic branches deploy
  preview URLs only after they're merged to `staging`. (Acceptable: the
  branch strategy already calls for verifying on staging.)
- Build minutes are consumed on every push and PR. For a personal site this
  is well under the free 2,000 min/month for private repos. For unlimited
  free minutes a self-hosted runner is an option later — see the closing
  note in `docs/runbooks/deploy-cloudflare-pages.md`.

## Reversibility

Two separate axes can be reversed independently.

### Switch back to Cloudflare Pages (away from Workers + static assets)

1. Create a Pages project named `mhamza-space` (Direct Upload flow at
   `https://dash.cloudflare.com/<account-id>/pages/new/upload-assets`).
2. Replace the workflow's deploy command with
   `pages deploy dist --project-name=mhamza-space --branch=${{ github.ref_name }}`.
3. Delete `wrangler.toml`.
4. Optionally delete the existing Workers (`mhamza-space`, `mhamza-space-staging`).

### Switch back to native Cloudflare Git integration

1. In the Worker / Pages project → connect to the GitHub repo, set
   production branch `main`, build command `pnpm build`, output `dist`.
2. Remove the `deploy` job from `.github/workflows/ci-cd.yml` (keep
   `build` for PR-time checks).
3. Drop the two `CLOUDFLARE_*` GitHub secrets.

Each axis is < 10 minutes; neither decision is load-bearing.
