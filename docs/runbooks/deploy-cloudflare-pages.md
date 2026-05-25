# Runbook — Deploy to Cloudflare Pages

Connects the GitHub repo to Cloudflare Pages so every push to `main` deploys
to production (mhamza.space) and every push to `staging` (or any other
branch) deploys to a preview URL.

This is a **one-time setup**. After it's done, deployment happens
automatically on `git push`. See [ADR 0001](../decisions/0001-static-cloudflare-pages.md)
for the why.

## Prerequisites

- [ ] Cloudflare account (free tier is fine).
- [ ] GitHub repo `hamzawork1/kb-blogs` accessible to you.
- [ ] Domain `mhamza.space` either already on Cloudflare DNS, or ready to be
      pointed there.

## Steps

### 1. Connect the repo

1. Cloudflare dashboard → **Workers & Pages** → **Create application** →
   **Pages** tab → **Connect to Git**.
2. Pick **GitHub** as the provider. Authorise Cloudflare to access the
   `hamzawork1/kb-blogs` repo (you can grant access to that one repo only).
3. Select **kb-blogs**.

### 2. Build settings

| Field | Value |
|---|---|
| Project name | `mhamza-space` (used as a subdomain on `pages.dev` until the custom domain is attached) |
| Production branch | `main` |
| Framework preset | **Astro** (auto-detected) — if not, leave blank, set build cmd manually |
| Build command | `pnpm build` |
| Build output directory | `dist` |
| Root directory | `/` (leave default) |

### 3. Environment variables

Under **Settings → Environment variables → Production**, add:

| Key | Value | Why |
|---|---|---|
| `NODE_VERSION` | `20` | Pin a known-good Node major; avoids surprises when Cloudflare bumps defaults |
| `PNPM_VERSION` | `10.27.0` | Match `packageManager` in `package.json` (only needed if auto-detect misfires) |

Add the same set under **Preview** so non-`main` branches behave the same way.

> Don't add the `GISCUS_*` variables yet — Giscus is disabled.

### 4. First deploy

Click **Save and deploy**. The first build runs from the current `main` tip.
Wait for the deploy to go green. Visit the temporary `*.pages.dev` URL to
verify the site loads.

### 5. Custom domain — `mhamza.space`

1. In the Pages project → **Custom domains** → **Set up a custom domain**.
2. Enter `mhamza.space`. Cloudflare will check DNS and either:
   - Auto-add the record (if the zone is on Cloudflare DNS already), or
   - Show you the CNAME / record to add at your registrar.
3. Add `www.mhamza.space` as a second custom domain pointing to the same
   project (Cloudflare will issue a 301 to the apex automatically).
4. Wait for SSL provisioning — usually < 2 minutes for Cloudflare-managed DNS.

### 6. Preview deploys for `staging`

Nothing to configure — Cloudflare Pages automatically builds **every** branch
that isn't `main` as a preview deploy. The preview URL appears in the GitHub
PR check (e.g. `https://<sha>.mhamza-space.pages.dev`).

If you want a stable URL like `staging.mhamza.space`:

1. Pages project → **Custom domains** → add `staging.mhamza.space`.
2. Assign it to the **staging** branch under
   **Settings → Branch deployments → Custom branch aliases**.

## Verification

After setup, verify all four:

- [ ] `git push origin main` triggers a production build.
- [ ] Production URL `https://mhamza.space` returns 200, search works
      (Pagefind hits dist).
- [ ] `git push origin staging` (or any topic branch) triggers a preview build.
- [ ] Preview URL is posted as a check on the GitHub PR.

## Rollback

If a bad build ships to production:

1. Cloudflare Pages dashboard → **Deployments** → find the last good prod build.
2. Click `...` → **Rollback to this deployment**.
3. Production is restored within seconds (DNS unchanged).

Then fix the offending commit on a topic branch, PR back through staging.

## Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| Build fails with `pnpm: command not found` | Add `PNPM_VERSION` env var, or switch build command to `npx pnpm@10.27.0 build`. |
| Build succeeds but search is broken | `postbuild` didn't run. Confirm `postbuild` script in `package.json` and that build output is `dist` (not `dist/client`). |
| Custom domain stuck on "Verifying" | Check the DNS record actually points to `mhamza-space.pages.dev`. Cloudflare DNS-managed zones usually self-resolve in seconds. |
| 404s on blog post URLs locally vs. live | All routes must come from `getStaticPaths` — a draft / missing entry will 404 only when published. |

## Notes during initial setup

> _This section is filled in live during the first walkthrough. Add any
> surprises, screenshots, or specifics encountered._

- [ ] _(to be filled)_
