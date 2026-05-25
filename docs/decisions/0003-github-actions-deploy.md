# ADR 0003 — Deploy via GitHub Actions instead of Cloudflare's native Git integration

- **Status:** Accepted
- **Date:** 2026-05-25
- **Deciders:** Muhammad Hamza
- **Supersedes parts of:** [ADR 0001](./0001-static-cloudflare-pages.md) (the host
  is still Cloudflare Pages — only the deploy mechanism changes).

## Context

Cloudflare Pages can deploy in two ways:

1. **Native Git integration** — Cloudflare watches the repo, builds on its own
   builders, and deploys on every push. Zero pipeline code.
2. **API / Wrangler upload** — you build elsewhere (GitHub Actions, locally,
   another CI) and push the pre-built `dist/` to Cloudflare's API. Cloudflare
   only serves; it doesn't build.

The user is an Azure DevOps engineer. Pipeline-as-code is the operating
mental model — every deploy should be an auditable Git workflow with
visible steps, gates, and the option to insert checks before shipping.

## Decision

Drive deploys from **GitHub Actions** using the `cloudflare/wrangler-action@v3`
action. Cloudflare Pages is used purely as a CDN host; the build happens
inside `.github/workflows/ci-cd.yml`.

The workflow has two jobs:

| Job | Trigger | What it does |
|---|---|---|
| **build** | every PR + every push to `main`/`staging` | `pnpm install --frozen-lockfile`, `pnpm lint`, `pnpm build`, verify Pagefind index, upload `dist/` as artifact |
| **deploy** | only push to `main` or `staging` (not PRs) | downloads the build artifact, runs `wrangler pages deploy dist --branch=<ref>` |

`--branch=${{ github.ref_name }}` makes Cloudflare Pages treat the `main`
push as a production deploy for the project and any other branch as a
preview.

## Alternatives considered

| Option | Pros | Cons | Verdict |
|---|---|---|---|
| **GitHub Actions + Wrangler** (chosen) | Full pipeline control; one tool for build, lint, deploy; easy to add type-check / scan / preview-link / Slack-notify steps later; matches the user's DevOps muscle memory; failures are debuggable inside the GH UI; secrets and protections live with the repo. | One more file to maintain; CI minutes consumed (well within free tier). | ✅ Selected |
| Native Cloudflare Pages Git integration | Zero pipeline code; fastest to ship initially; preview URL on every PR for free. | Build runs in Cloudflare's environment with limited visibility; can't gate on extra checks without reintroducing GH Actions anyway; harder to test locally what CI does. | Rejected |
| `cloudflare/pages-action@v1` | Pages-specific, simple. | Deprecated in favour of `wrangler-action`. | Rejected |

## Consequences

- The repo needs two secrets on the GitHub side:
  - `CLOUDFLARE_API_TOKEN` — scope `Account → Cloudflare Pages → Edit`.
  - `CLOUDFLARE_ACCOUNT_ID` — visible in the Cloudflare dashboard's right
    sidebar.
- The Cloudflare Pages project (`mhamza-space`) must be **created manually**
  in the dashboard, but with **no Git connection** — its purpose is just to
  name a deployment target. See
  [`docs/runbooks/deploy-cloudflare-pages.md`](../runbooks/deploy-cloudflare-pages.md)
  for the exact steps.
- The "production branch" set inside the Cloudflare Pages project must match
  what the workflow treats as production (`main`).
- PR previews are not automatic with this setup. Topic branches deploy
  preview URLs only after they're merged to `staging`. (Acceptable: the
  branch strategy already calls for verifying via the staging branch.)
- Build minutes are consumed on every push and PR. For a personal site this
  is well under the free 2,000 min/month for private repos.

## Reversibility

To switch back to native Cloudflare Git integration:

1. In the Pages project → **Settings → Builds & deployments → Source** → connect
   to the GitHub repo, set production branch `main`, build command
   `pnpm build`, output `dist`.
2. Delete `.github/workflows/ci-cd.yml` (or remove the `deploy` job; keep
   `build` for PR-time checks).
3. Drop the two `CLOUDFLARE_*` GitHub secrets.

Reverse path is < 5 minutes; this decision is not load-bearing.
