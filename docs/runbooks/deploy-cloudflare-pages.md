# Runbook — Deploy to Cloudflare (Workers with static assets, via GitHub Actions)

Sets up the pipeline so every push to `main` deploys to production
(`mhamza.space`) and every push to `staging` deploys to a staging Worker.

**Architecture:** GitHub Actions builds the site
(`.github/workflows/ci-cd.yml`) and uploads the `dist/` output to a
Cloudflare **Worker with static assets** via Wrangler. Two environments
declared in `wrangler.toml` map to two Workers:

| Branch | Worker name | Public URL (initial) |
|---|---|---|
| `main` | `mhamza-space` | `mhamza-space.<subdomain>.workers.dev` → custom domain `mhamza.space` later |
| `staging` | `mhamza-space-staging` | `mhamza-space-staging.<subdomain>.workers.dev` → optional `staging.mhamza.space` later |

Why Workers (not Pages)? See [ADR 0003](../decisions/0003-github-actions-deploy.md).

This is a **one-time setup**. After it's done, every `git push` triggers
a deploy through the workflow.

## Prerequisites

- [ ] Cloudflare account (free tier).
- [ ] GitHub repo `hamzawork1/kb-blogs` with admin rights (to add secrets).
- [ ] Domain `mhamza.space` available to point at Cloudflare (later step).

---

## Step 1 — Workers already exist (mostly)

If you uploaded any file via Cloudflare's "Upload assets" flow, the
production Worker (`mhamza-space`) is already created. The first
`wrangler deploy --env production` from CI will overwrite its current
content with the built Astro site. **No manual cleanup is needed.**

The staging Worker (`mhamza-space-staging`) doesn't exist yet — Wrangler
will create it on the first push to the `staging` branch.

> If the Worker has a different name than `mhamza-space`, either rename it
> in the dashboard or update `name` and `[env.production].name` in
> `wrangler.toml` to match.

## Step 2 — Get the Cloudflare credentials

### 2a. Account ID

In the Cloudflare dashboard's right sidebar (visible on most pages) the
**Account ID** is a long hex string. It also appears in the URL right
after `dash.cloudflare.com/`:

```
https://dash.cloudflare.com/a1aa18c0bffdf49aa9119d570785d905/...
                            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
                            this is the Account ID
```

Copy it; you'll paste it into a GitHub secret in Step 3.

### 2b. API token

1. Profile menu (top-right) → **My Profile** → **API Tokens** → **Create Token**.
2. Pick **Custom token** → **Get started**.
3. Set:

   | Field | Value |
   |---|---|
   | Token name | `mhamza-space-deploy` |
   | Permission 1 | **Account** → **Workers Scripts** → **Edit** |
   | Permission 2 | **Account** → **Account Settings** → **Read** |
   | Account Resources | Include → All accounts (or just yours) |
   | Zone Resources | Default (`All zones from an account`) — only needed when you wire up the custom domain later |
   | Client IP filter / TTL | Optional |

4. **Continue to summary** → **Create Token**.
5. Copy the token **once** — Cloudflare won't show it again. Paste it
   into the GitHub secret in Step 3.

## Step 3 — Add the GitHub secrets

Repo → **Settings** → **Secrets and variables** → **Actions** →
**New repository secret**:

| Name | Value |
|---|---|
| `CLOUDFLARE_API_TOKEN` | the token from Step 2b |
| `CLOUDFLARE_ACCOUNT_ID` | the ID from Step 2a |

Both stay inside GitHub's encrypted secret store. They are injected into
workflow runs as masked environment values.

## Step 4 — Trigger the first deploy

`.github/workflows/ci-cd.yml` deploys on push to `main` or `staging`.
Trigger the first staging deploy:

```powershell
# from your feature branch
git checkout staging
git pull
git merge feat/<your-branch> --no-ff
git push origin staging
```

Watch the run live: GitHub repo → **Actions** tab → pick the latest run →
expand **Build & Lint** then **Deploy to Cloudflare Pages**. The final
step prints the deployed Worker URL.

Visit the URL to confirm the site loads, search works (Pagefind index is
inside `dist/`), and posts render.

## Step 5 — Custom domain — `mhamza.space`

> Wait until at least one successful production deploy has landed before
> attaching the custom domain.

1. In the Cloudflare dashboard, open the production Worker
   (`mhamza-space`) → **Domains** tab.
2. **Add custom domain** → `mhamza.space`.
   - If `mhamza.space` is already on Cloudflare DNS, the record is added
     for you.
   - Otherwise, point the apex (or a CNAME on a subdomain) at the
     `workers.dev` target Cloudflare gives you.
3. Add `www.mhamza.space` as a second domain — Cloudflare auto-redirects
   apex/www traffic.
4. SSL certs provision within a couple of minutes on Cloudflare-managed
   zones.

### Optional — `staging.mhamza.space`

After the staging Worker has been created by its first deploy:

1. Open `mhamza-space-staging` → **Domains** → add `staging.mhamza.space`.
2. DNS record is added automatically if the zone is on Cloudflare.

---

## Verification checklist

- [ ] `git push origin staging` triggers a workflow run.
- [ ] Workflow's **build** job passes (lint + Astro build + Pagefind
      index assertion).
- [ ] Workflow's **deploy** job posts a Worker URL.
- [ ] Visiting the URL loads the site; `/blog/<slug>` renders correctly;
      `/blog/<slug>/` (trailing slash variant) also works; search returns
      hits; OG meta in `view-source` references `https://mhamza.space`.
- [ ] After merging staging → main and pushing main, production deploys
      to `mhamza-space` Worker (and `mhamza.space` once the custom domain
      is attached).

## Rollback

If a bad build ships to production:

1. Cloudflare dashboard → `mhamza-space` Worker → **Deployments** tab.
2. Find the last good deployment → `...` menu → **Rollback to this
   deployment**.
3. Production restores within seconds (DNS unchanged).
4. Fix the offending commit on a topic branch off `staging`, PR through
   `staging`, ship the corrected version through the normal flow.

## Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| **Deploy fails: "Authentication error [code: 10000]"** | `CLOUDFLARE_API_TOKEN` is wrong / expired / missing the `Workers Scripts:Edit` permission. Regenerate with the right scope, update the GitHub secret. |
| **Deploy fails: "binding type unknown" / odd parser errors** | `wrangler.toml` was edited with a typo. Run `pnpm dlx wrangler deploy --env staging --dry-run` locally to validate. |
| **Deploy fails: "An asset directory is required" / missing `./dist`** | The `download-artifact` step didn't run, or the artifact name doesn't match. Confirm the `build` job uploaded `site-dist` and the `deploy` job downloads it to `dist`. |
| **Build job fails with `ERR_PNPM_OUTDATED_LOCKFILE`** | `pnpm-lock.yaml` is out of sync with `package.json`. Run `pnpm install` locally, commit the updated lockfile, push. |
| **Site deploys but URLs 404** | `not_found_handling = "404-page"` is set, but `dist/404.html` wasn't generated. Confirm `src/pages/404.astro` exists and built. |
| **Workflow doesn't run on push** | Confirm the file is at `.github/workflows/ci-cd.yml` (correct path), YAML is valid (Actions tab shows parse errors), and `on.push.branches` includes the branch you pushed. |
| **Search returns no results live** | `dist/pagefind/` wasn't generated. Check `package.json` → `postbuild` is `pagefind --site dist`. |

---

## When this hits the free-tier ceiling

GitHub Actions on a private repo: 2,000 minutes/month free. Each deploy
run on this project takes ~2 minutes (build + deploy). That comfortably
supports several deploys per day with margin.

If usage outgrows the free tier, options:

1. **Self-hosted runner** — register a runner on a personal VM or laptop
   (`runs-on: self-hosted`), unlimited minutes. Trade-off: you maintain
   the runner; the workflow runs on whatever credentials and network the
   runner has.
2. **Public the repo** — public GitHub repos get unlimited GitHub-hosted
   Actions minutes. Trade-off: source becomes visible (probably fine for
   a personal portfolio).
3. **Buy more minutes** — $0.008/min for additional minutes on the free
   plan.

---

## Notes during initial setup

> _Append real observations from the first time you run through this
> document — surprising clicks, DNS quirks, anything that would help
> future-you do it faster next time._

- 2026-05-25 — Cloudflare's UI now defaults static-asset uploads to a
  **Worker** (not a Pages project). The "Pages" Direct Upload flow is
  hidden behind `https://dash.cloudflare.com/<account-id>/pages/new/upload-assets`.
  We embraced the Worker route per ADR 0003.
- 2026-05-25 — First successful staging deploy created a Worker named
  **`kb-blogs-staging`** instead of `mhamza-space-staging` declared in
  `wrangler.toml`'s `[env.staging].name`. Cloudflare appears to resolve
  the env-block `name` against pre-existing project context on the
  account (possibly the GitHub repo name `kb-blogs` getting picked up
  somewhere), not against the literal value in the TOML.
  **Fix:** Force the Worker name via the CLI `--name` flag in the
  deploy command:
  `wrangler deploy --env <env> --name <worker-name>`.
  CLI `--name` overrides everything — config, environment defaults,
  pre-existing project context. **Lesson:** when a Cloudflare account
  has any history with similar-looking names, never trust env-block
  `name` alone — always pin via CLI.
- 2026-05-25 — First staging deploy (PR #2 merge) failed because
  `cloudflare/wrangler-action@v3` defaults to installing **Wrangler 3.90.0**.
  Wrangler 3 does NOT fully support static-only Workers — it treats
  `[assets] directory = ...` as auxiliary, still demands a `main` JS
  entry-point, and fails to parse `[env.staging]` blocks that don't
  declare one. Two errors surfaced together:
  - `No environment found in configuration with name "staging".`
  - `Missing entry-point: The entry-point should be specified via the
    command line ... or the main config field.`
  Fix: pin `wranglerVersion: "4"` in the workflow step. With Wrangler 4
  the `[assets]` block is first-class and static-only Workers deploy
  without a `main`. **Lesson:** when an action wraps a CLI whose major
  version matters for a feature, always pin the CLI version explicitly
  — don't rely on the action's default.
- 2026-05-25 — Custom domain `staging.mhamza.space` attached cleanly via
  the Worker → Domains tab. Cloudflare auto-created the DNS record in the
  `mhamza.space` zone (already on Cloudflare DNS) and provisioned SSL
  within ~1 minute. **Both** the custom domain and the default
  `mhamza-space-staging.devops-engineer099.workers.dev` URL served the
  site at first. The `.workers.dev` URL stays active by default — to
  enforce single-source-of-truth, disable it from the Worker → Domains
  tab (toggle next to the `.workers.dev` entry). After disabling, only
  the custom domain reaches the Worker.
- _(more to be filled during the first production deploy + custom domain wiring for mhamza.space)_
