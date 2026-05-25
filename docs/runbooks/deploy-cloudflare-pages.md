# Runbook — Deploy to Cloudflare Pages (via GitHub Actions)

Sets up the pipeline so every push to `main` deploys to production
(`mhamza.space`) and every push to `staging` deploys to a preview URL.

**Architecture:** GitHub Actions builds the site (`.github/workflows/ci-cd.yml`)
and uploads the `dist/` output to Cloudflare Pages via Wrangler. Cloudflare
Pages is only a host — it does not pull from Git directly. See
[ADR 0003](../decisions/0003-github-actions-deploy.md) for the rationale.

This is a **one-time setup**. After it's done, every `git push` triggers a
deploy through the workflow.

## Prerequisites

- [ ] Cloudflare account (free tier).
- [ ] GitHub repo `hamzawork1/kb-blogs` accessible to you, with admin rights
      (needed to add secrets).
- [ ] Domain `mhamza.space` ready (either already on Cloudflare DNS, or you
      can point it there).

---

## Step 1 — Create an empty Cloudflare Pages project

The Pages project is just a named deployment target. **Do not** connect it
to Git — Wrangler will push deploys to it from GitHub Actions.

1. Cloudflare dashboard → **Workers & Pages** → **Create application** →
   **Pages** tab.
2. Choose **Upload assets** (NOT "Connect to Git").
3. Project name: **`mhamza-space`** (must match the value in
   `.github/workflows/ci-cd.yml` → `--project-name=mhamza-space`).
4. You can skip the manual asset upload at this point — just click through
   to create the project. The first real deploy will come from Actions.
5. After creation, go to the project → **Settings → Builds & deployments**
   and set:
   - **Production branch:** `main`
   - **Preview deployments:** "Only from selected branches" → add `staging`
     (or leave as "All non-Production branches" if you want preview deploys
     for any branch you ever push directly).

## Step 2 — Get the Cloudflare credentials

### 2a. Account ID

In the Cloudflare dashboard's right sidebar (visible on most pages), under
**Account ID**, copy the long hex string.

### 2b. API token

1. Profile menu → **My Profile** → **API Tokens** → **Create Token**.
2. Pick the **Custom token** template.
3. Permissions:
   - **Account** → **Cloudflare Pages** → **Edit**
   - **Account** → **Account Settings** → **Read** (optional but commonly required)
4. Account Resources: include the specific account you'll deploy from.
5. (Optional but recommended) Add a **TTL** and a **client IP filter** if you
   want to limit blast radius.
6. **Continue to summary** → **Create Token**. Copy the token value (shown
   only once).

## Step 3 — Add the GitHub secrets

1. Repo → **Settings** → **Secrets and variables** → **Actions** →
   **New repository secret**. Add both:

   | Name | Value |
   |---|---|
   | `CLOUDFLARE_API_TOKEN` | the token from Step 2b |
   | `CLOUDFLARE_ACCOUNT_ID` | the ID from Step 2a |

2. **Do not commit either value to the repo.** They live only in GitHub's
   encrypted secret store and are injected at workflow runtime.

## Step 4 — Trigger the first deploy

The workflow `.github/workflows/ci-cd.yml` already deploys on push to
`main` or `staging`. Trigger it by pushing to one of those branches:

```powershell
# from your feature branch
git checkout staging
git merge feat/<your-branch> --no-ff
git push origin staging
```

Watch the run live: **Actions tab** on GitHub → pick the latest run → expand
**Build & Lint** then **Deploy to Cloudflare Pages**. The final step prints
a preview URL.

Visit the preview URL to confirm the site loads. Search (`/`) should work
because the Pagefind index is part of `dist/`.

## Step 5 — Custom domain — `mhamza.space`

1. Pages project → **Custom domains** → **Set up a custom domain**.
2. Enter `mhamza.space`.
   - If `mhamza.space` is already on Cloudflare DNS, the record is added
     automatically.
   - Otherwise, copy the CNAME target Cloudflare gives you and add it at
     your domain registrar.
3. Add `www.mhamza.space` as a second custom domain — Cloudflare will issue
     a 301 to the apex automatically.
4. Wait for SSL provisioning — usually < 2 minutes for Cloudflare-managed
   DNS zones.

### Optional — pretty staging URL

By default the staging preview URL looks like
`https://staging.mhamza-space.pages.dev`. To use `staging.mhamza.space`:

1. Pages project → **Custom domains** → add `staging.mhamza.space`.
2. **Settings → Branch deployments → Custom branch aliases** → map the
   custom domain to the `staging` branch.

---

## Verification checklist

- [ ] `git push origin staging` triggers a workflow run.
- [ ] Workflow's **build** job passes (lint + build green).
- [ ] Workflow's **deploy** job posts a Cloudflare preview URL.
- [ ] Visiting the preview URL loads the site, search works, post pages
      render, OG tags are correct.
- [ ] After merging staging → main and pushing main, production deploy
      lands at `mhamza.space`.

## Rollback

If a bad build ships to production:

1. Cloudflare Pages dashboard → **Deployments** → find the last good
   production build (filter by branch `main`).
2. Click `...` → **Rollback to this deployment**.
3. Production restores within seconds (DNS unchanged).
4. Fix the offending commit on a topic branch off staging, PR through
   staging, then ship a corrected version through the normal flow.

## Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| **Deploy fails: "Error: Authentication error [code: 10000]"** | `CLOUDFLARE_API_TOKEN` is wrong or expired. Regenerate at Cloudflare → My Profile → API Tokens. Update the GitHub secret. |
| **Deploy fails: "Could not find project mhamza-space"** | The `--project-name` in the workflow doesn't match the actual project name in Cloudflare. Either rename one or the other so they match. |
| **Build job fails with `ERR_PNPM_OUTDATED_LOCKFILE`** | `pnpm-lock.yaml` is out of sync with `package.json`. Run `pnpm install` locally, commit the updated lockfile, push. |
| **Custom domain stuck on "Verifying"** | Check the DNS record points to `mhamza-space.pages.dev`. Cloudflare-managed DNS zones usually self-resolve in seconds. Otherwise wait for the registrar's TTL. |
| **Site deploys but search returns empty** | `dist/pagefind/` wasn't generated. Check the `postbuild` script in `package.json` is `pagefind --site dist` (not `dist/client`). |
| **Workflow doesn't run on push** | Confirm the file is at `.github/workflows/ci-cd.yml` (correct path) and YAML is valid (Actions tab will show parse errors). |

---

## Notes during initial setup

> _Append real observations from the first time you run through this
> document — surprising clicks, DNS quirks, anything that would help
> future-you do it faster next time._

- [ ] _(to be filled)_
