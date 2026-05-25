# 08 — Troubleshooting

When things go wrong, this is the file to open first. Organised by symptom (what you see) rather than cause (what you suspect), because in practice you almost always start with the symptom.

For each entry: **what you see → likely cause → fix → how to prevent next time**.

---

## Local development

### `pnpm dev` exits immediately with "Unable to load your Astro config"

**Symptom (full):**
```
[astro] Unable to load your Astro config
ERROR: It seems you have not updated the preset Giscus configuration for comments!
```

**Cause:** Giscus is enabled in `astro.config.ts` with empty option values. The integration validates Giscus options at startup and refuses to start with a placeholder config.

**Fix:** Either:

- Disable Giscus: set `giscus: false` in `astro.config.ts` (and comment out the env-loading block above).
- Or fully configure it: fill in real `GISCUS_*` values in `.env` (template in `.env.example`).

**Prevent:** Giscus is currently off. If you ever enable it, treat the `.env` setup as part of the same PR.

### `pnpm dev` works but the page is blank / errors in browser console

**Cause:** Almost always a Vite HMR issue from rapid restart or branch-switching. The dev server's in-memory state got confused.

**Fix:**
1. Stop the dev server (Ctrl-C).
2. Delete `.astro/` (Astro's generated types cache).
3. Run `pnpm dev` again.

If that doesn't help: `rm -rf node_modules && pnpm install && pnpm dev`. Heavy-handed but reliable.

**Prevent:** Don't switch git branches while `pnpm dev` is running. Stop the dev server first.

### Search returns empty / "no results" for everything in `pnpm dev`

**Cause:** This is expected. Pagefind is a build-time index. The dev server serves a stub `pagefind.js` at `src/pages/pagefind/pagefind.js.ts` that always returns `{ results: [] }`. Real search only works on built output.

**Fix:** Use `pnpm build && pnpm preview` to test search locally. The preview server serves `dist/` which has the real Pagefind index.

**Prevent:** N/A — this is by design. Don't try to "fix" the stub.

### `pnpm install` complains about lockfile

**Symptom:**
```
ERR_PNPM_LOCKFILE_BREAKING_CHANGE
ERR_PNPM_OUTDATED_LOCKFILE
```

**Cause:** Lockfile and `package.json` drifted apart. Usually because someone ran `npm install` (creates `package-lock.json`) or because a `package.json` dependency was edited by hand without updating the lockfile.

**Fix:**
```powershell
# If a package-lock.json exists, delete it (we use pnpm only)
del package-lock.json

# Regenerate pnpm-lock.yaml
pnpm install
```

If you can't regenerate locally (no network), the alternative is `pnpm install --no-frozen-lockfile` to let pnpm update the lockfile in place.

**Prevent:** Always use `pnpm <cmd>`. The `packageManager` field in `package.json` makes `corepack` enforce this if it's enabled.

---

## Build (`pnpm build`)

### `Could not find tag "<id>"`

**Symptom (full):**
```
Could not find tag "<id>" in collection "tags".
```

**Cause:** A post's frontmatter has a tag that's not registered in `src/content/tags.json`. The schema validates references — unknown tags fail the build.

**Fix:** Either remove the tag from the post, or add it to `tags.json`. To add: see [06 — Daily workflows](./06-daily-workflows.md#add-a-new-tag) (don't forget the cover-banner generation).

**Prevent:** When introducing a new topic, decide upfront whether it deserves a new tag. If yes, do the `tags.json` + banner addition as the first commit of the topic branch — before writing the post that uses it.

### `Failed to resolve image '../assets/xyz.png'`

**Cause:** The post's `image:` frontmatter points at a file that doesn't exist (typo in filename, wrong path, image not committed yet).

**Fix:** Either correct the path or add the missing file.

**Prevent:** Always reference a cover banner that already exists: one of the seven tag banners in `src/content/assets/`. Generate new ones via the script *before* writing the post that uses them.

### `Image is required`

**Cause:** Missing `image:` field in the post's frontmatter. The schema requires it.

**Fix:** Add `image: "../assets/<tag>-cover.png"`.

**Prevent:** Use the existing post `azure-vm-public-ip-upgrade-basic-to-standard.mdx` as a frontmatter template — copy + edit.

### `Astro can't validate <field>: <reason>`

**Cause:** Frontmatter doesn't match the Zod schema in `src/content.config.ts`. Common variants:

- Date in wrong format: use `YYYY-MM-DD` (no quotes around it — YAML parses it as a date).
- `tags:` is not an array: must be a list with hyphens, even for one tag.
- Required field missing.

**Fix:** Read the error — Zod produces specific messages. Fix the frontmatter accordingly.

**Prevent:** Copy frontmatter from an existing valid post when starting a new one.

### Build succeeds but no `dist/pagefind/` directory

**Cause:** Pagefind's `postbuild` script didn't find any `data-pagefind-body` elements to index. Likely the article template was edited and the attribute was removed.

**Fix:** Check `src/pages/blog/[post].astro` — the outer `<article>` element should have `data-pagefind-body`. Restore it if missing.

**Prevent:** The CI's "Verify Pagefind index exists" step catches this. Don't disable that check.

### Build hangs or runs forever

**Cause:** Almost always a runaway image or MDX file. Astro processes images sequentially; a huge PNG (say, 50 MB) can take minutes. Or an MDX file with an infinite-loop component.

**Fix:**
- Check `src/content/assets/` and `src/assets/` for unexpectedly large files. Image sizes should be under 500 KB each, usually.
- Check the post you most recently edited — did you embed anything experimental?

**Prevent:** Stick to the standard image sizes documented in [07 — Theme structure](./07-theme-structure.md#cover-banner-system-recap).

---

## Lint (`pnpm lint`)

### Biome complains about formatting

**Symptom:** `pnpm lint` reports formatting violations.

**Fix:** `pnpm lint:fix` to auto-fix. Review the diff. Commit.

**Prevent:** Install the Biome VS Code / Cursor extension to format on save. Then formatting is never a CI failure.

### Biome flags a real bug

The rule that fires identifies the bug. Read the error message and the line it points at.

If you genuinely think the rule is wrong, you can disable it for one line:

```typescript
// biome-ignore lint/<rule>: <reason for ignoring>
const problematicLine = ...;
```

Use sparingly. Ignoring lint rules is a smell.

---

## CI (GitHub Actions)

### Build job fails with "Node.js v20.x is not supported"

**Cause:** The workflow's `node-version` is set to 20. Astro 6 requires Node ≥22.12.

**Fix:** Open `.github/workflows/ci-cd.yml`. Set:
```yaml
- uses: actions/setup-node@v4
  with:
    node-version: 22
    cache: pnpm
```

Commit + push.

**Prevent:** This was fixed in PR #2. If a future Astro version requires Node 24, repeat the same pattern.

### Build job fails with "frozen lockfile" / "lockfile out of sync"

**Cause:** `pnpm-lock.yaml` doesn't match `package.json`. Someone changed `package.json` without running `pnpm install` locally, or someone committed a partial lockfile update.

**Fix locally:**
```powershell
pnpm install      # regenerate lockfile cleanly
git add pnpm-lock.yaml
git commit -m "chore: sync pnpm-lock.yaml"
git push
```

**Prevent:** Always run `pnpm install` after editing `package.json`. The `--frozen-lockfile` flag in CI catches drift; that's the safety net.

### Deploy job fails with "Authentication error [code: 10000]"

**Cause:** The `CLOUDFLARE_API_TOKEN` GitHub secret is wrong, expired, or missing.

**Fix:**
1. Generate a new token at <https://dash.cloudflare.com/profile/api-tokens>. Scope: `Account → Workers Scripts → Edit` + `Account → Account Settings → Read`.
2. Update the GitHub secret: repo Settings → Secrets and variables → Actions → `CLOUDFLARE_API_TOKEN` → Update.
3. Re-run the failed workflow.

**Prevent:** If the token has a TTL configured, set a calendar reminder a week before expiry.

### Deploy job fails with "Could not find project 'mhamza-space'"

**Cause:** Either the project name in the workflow's deploy command doesn't match what Cloudflare has, or the token doesn't have access to the right account.

**Fix:**
1. Confirm the project exists in Cloudflare dashboard with exactly that name (case-sensitive).
2. Confirm the token's scope includes the right account.
3. Check `CLOUDFLARE_ACCOUNT_ID` matches the account that owns the project.

**Prevent:** N/A — this was sorted during initial setup. If you ever create a new project, update the workflow's `--name` argument to match.

### Deploy job fails with "No environment found in configuration with name 'staging'"

**Cause:** Wrangler can't find an `[env.staging]` block in `wrangler.toml`. Two sub-causes:

1. The block is genuinely missing (someone deleted it).
2. Wrangler 3 is being used and doesn't parse `[env.<name>]` blocks for static-only Workers.

**Fix:**

For sub-cause 1: restore the block. See `wrangler.toml` history in git.

For sub-cause 2: the workflow has `wranglerVersion: "4"`. If it's missing or pointed at a v3 release, fix:

```yaml
- uses: cloudflare/wrangler-action@v3
  with:
    wranglerVersion: "4"
    # ...
```

**Prevent:** The pin is in place. Don't remove it.

### Deploy job fails with "Missing entry-point"

**Cause:** Wrangler is trying to find a JavaScript `main` file — i.e. it thinks this is a code Worker, not a static-asset Worker.

This happens when Wrangler 3 (or an old config syntax) is in play. Wrangler 4's `[assets]` directive tells Wrangler "this Worker has no main entry; just serve the assets". Wrangler 3 doesn't understand that.

**Fix:** Same as the previous one — confirm `wranglerVersion: "4"` is set.

**Prevent:** Same.

### Deploy succeeds but the Worker has the wrong name

**Symptom:** Deploy logs say `Uploaded kb-blogs-staging` instead of `Uploaded mhamza-space-staging`. The URL is `https://kb-blogs-staging.devops-engineer099.workers.dev` instead of `https://mhamza-space-staging.devops-engineer099.workers.dev`.

**Cause:** Cloudflare's resolution of `[env.<name>].name` is overridden by pre-existing project context on the account. We hit this on 2026-05-25. The exact root cause wasn't determined.

**Fix:** The workflow now passes `--name <name>` explicitly in the deploy command:

```yaml
command: deploy --env <env> --name <name>
```

That bypasses whatever Cloudflare is doing with `[env.<name>].name` and forces the name.

**Prevent:** Don't remove the `--name` flag from the workflow. If you do ever want to rename a Worker, change both the workflow and `wrangler.toml`, deploy, then delete the orphan Worker from the dashboard.

### Deploy succeeds but the site shows old content

**Cause:** Browser or CDN cache.

**Fix:**
- Hard refresh in the browser: Ctrl+Shift+R (or Cmd+Shift+R on Mac).
- If still seeing old content from many browsers: Cloudflare dashboard → Caching → Purge Everything. (Use sparingly — it costs CDN-cache benefit for the next few minutes.)

**Prevent:** N/A — caching is generally what you want. Just remember to hard-refresh when verifying a deploy.

### Workflow doesn't trigger on push

**Cause:** The workflow file might be invalid YAML or might have a syntax error in a condition. The Actions tab usually shows a "Workflow file has a parse error" entry.

**Fix:** Read the parse error in the Actions UI. Fix the YAML. If the file isn't at `.github/workflows/ci-cd.yml`, it won't run — confirm the path.

**Prevent:** Test workflow file changes by pushing them to a topic branch first (the PR's CI run validates the YAML).

---

## Cloudflare / Deploy / Domain

### Custom domain stuck on "Verifying"

**Cause:** DNS hasn't propagated to Cloudflare's verification system. Usually only happens if the domain isn't on Cloudflare DNS.

**Fix:**
- If the domain is on Cloudflare DNS: wait 2-3 minutes; usually resolves automatically.
- If not on Cloudflare DNS: add the CNAME / record at your registrar pointing at the Worker's `<name>.<subdomain>.workers.dev`. Wait for DNS TTL.

**Prevent:** Keep `mhamza.space` on Cloudflare DNS. The integration is seamless when you do.

### Site shows 404 on `/blog/<slug>` for a freshly-merged post

**Cause:** Either:

1. The deploy hasn't completed yet (give it 1-2 minutes from merge).
2. The post has `draft: true` in its frontmatter.
3. The slug doesn't match what you typed (case, hyphens, etc.).

**Fix:**
1. Check the Actions tab — is the deploy run completed and green?
2. Open the post's `.mdx` file, confirm `draft: false` (or absent).
3. Match the URL exactly to the post's filename (without `.mdx`).

**Prevent:** N/A.

### Site shows 404 on every page

**Cause:** Likely the Cloudflare Worker is misconfigured or pointed at the wrong assets. Or the deploy failed silently (unlikely with our CI, but possible).

**Fix:**
1. Cloudflare dashboard → Workers & Pages → click into the affected Worker.
2. Check the latest deployment — does it list 30+ assets? If it lists 0, the upload failed.
3. Check the Worker's Settings → Triggers → confirm the right custom domain is mapped.
4. Last resort: rollback to the previous deployment from the Deployments tab.

**Prevent:** Always verify on staging before promoting to main.

### `.workers.dev` URL is still accessible after you "disabled" it

**Cause:** Multiple Workers might exist with overlapping names. Deleting / disabling one Worker doesn't affect another.

**Fix:**
1. Confirm which Worker has the URL: Cloudflare dashboard → that Worker → Domains tab. Find the `.workers.dev` entry. Is it still listed as enabled?
2. If yes — disable it again. The toggle might not have saved the first time.
3. If no — but the URL still serves — the Cloudflare CDN may be caching the response. Hard-refresh; if still cached, Cloudflare Caching → Purge Everything on the Worker.

**Prevent:** After disabling, verify with `curl -I https://<worker>.<subdomain>.workers.dev`. The response should be 404 or similar.

---

## Git / GitHub

### `git push` rejected: "fetch first"

**Cause:** Someone (or another machine) pushed to the same branch between your last pull and your push.

**Fix:**
```powershell
git pull --rebase origin <branch>
# resolve any conflicts
git push
```

**Prevent:** Always `git pull --ff-only origin <branch>` before starting a topic branch off it.

### Force-push needed

If you find yourself wanting to force-push to a long-lived branch (`main` / `staging`), STOP and think. Once in the project's life — the history squash on 2026-05-25 — was deliberate and authorised. Otherwise force-push is destructive.

**If you're certain:** use `--force-with-lease` instead of `--force`. The `-with-lease` form refuses to overwrite if someone else has pushed in the meantime, which gives you a second chance to notice.

**Prevent:** Never force-push to a branch that's been merged into. Topic branches that haven't been merged are fair game.

### Merge conflict on PR

**Cause:** `staging` has moved since you branched off it; your topic branch has changes that don't apply cleanly.

**Fix:**
```powershell
git checkout <topic-branch>
git fetch origin
git merge origin/staging
# resolve conflicts in the marked files
git add <resolved-files>
git commit
git push
```

(You can also `git rebase origin/staging` instead of `merge`. Merge is simpler and the project doesn't enforce linear history.)

**Prevent:** Keep topic branches short-lived. If a topic branch is open for more than a few days, periodically merge `staging` into it to stay current.

### "Working tree clean" but `git status` shows untracked files

**Cause:** Those files aren't tracked, so they're not part of the working tree's "dirty" state. They may need to be added to `.gitignore`.

**Fix:** Either:

- `git add <file>` if the file should be tracked.
- Add a pattern to `.gitignore` if it shouldn't ever be tracked.

**Prevent:** Periodically review untracked files in `git status` and decide their fate.

---

## Production deploy went bad

This is the highest-stakes failure. You merged `staging → main`, the deploy ran, and now mhamza.space is broken.

### Immediate response (under 60 seconds)

1. Cloudflare dashboard → Worker `mhamza-space` → **Deployments** tab.
2. Filter by branch `main`.
3. Click the previous (working) deployment.
4. **"Rollback to this deployment"** → confirm.

Production is restored within seconds. DNS is unchanged. SSL is unchanged. The bad deployment is still in the list but isn't serving traffic.

### After the rollback (no panic now)

1. **Open an issue or note** describing what broke.
2. **Branch off staging** (which has the bad change merged into it):
   ```powershell
   git checkout staging
   git pull --ff-only origin staging
   git checkout -b fix/production-incident-<short-name>
   ```
3. Diagnose and fix on this branch.
4. Re-test on `staging.mhamza.space`.
5. Open a new `staging → main` PR when confident.

### Common production-fail patterns

- **Bad image asset breaks layout:** find the image, fix the size / format, redeploy.
- **JavaScript error in a custom MDX component:** revert the offending post to `draft: true`, redeploy, then fix the component on a topic branch.
- **CSS regression makes the site unreadable on mobile:** revert the offending stylesheet commit, redeploy.

In every case the rollback buys you time. Take the time. Don't try to hotfix-and-merge on autopilot — you broke prod once, you don't want to break it twice in a row.

---

## "I don't know what's wrong — where do I start?"

A debugging checklist when you're stuck:

1. **Read the error.** Most CI logs and Astro errors are specific. Skip to the underlined line.
2. **Reproduce locally.** Can you trigger the same error with `pnpm build`? If yes, you have a tight feedback loop without waiting for CI.
3. **`git log` recently.** The bug usually entered via a recent commit. `git log --oneline -20` shows what changed.
4. **Bisect if needed.** `git bisect start; git bisect bad; git bisect good <last-known-good-sha>` — Git steps you through commits until you find the breaker.
5. **Check the runbook.** `docs/runbooks/deploy-cloudflare-pages.md` "Notes during initial setup" lists every weird thing we've actually hit.
6. **Check this file.** You're here.
7. **Check `CHANGELOG.md`.** What was the most recent intentional change? Could it relate?
8. **Ask for a fresh pair of eyes.** Even on a solo project, walking the problem out loud (or writing a Slack-style "rubber duck" post) often surfaces the answer.

If the answer doesn't appear in 30 minutes of focused debugging, take a break. Come back. Bugs that resist 30 minutes often dissolve in 10 after coffee.

---

Next: [09 — Decisions](./09-decisions.md)
