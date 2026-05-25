# 05 — CI/CD pipeline

A walkthrough of `.github/workflows/ci-cd.yml`. By the end you'll understand every line, every pinned version, and every guard. You'll also know exactly what happens when a PR is opened, when it's merged, and when something fails.

---

## The whole file

```yaml
name: CI/CD

on:
  push:
    branches: [main, staging]
  pull_request:
    branches: [main, staging]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}

jobs:
  build:
    name: Build & Lint
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up pnpm
        uses: pnpm/action-setup@v4
        with:
          version: 10.27.0
          run_install: false

      - name: Set up Node
        uses: actions/setup-node@v4
        with:
          node-version: 22
          cache: pnpm

      - name: Install dependencies
        run: pnpm install --frozen-lockfile

      - name: Lint (Biome)
        run: pnpm lint

      - name: Build (Astro + Pagefind index)
        run: pnpm build

      - name: Verify Pagefind index exists
        run: test -d dist/pagefind && echo "OK" || (echo "Pagefind index missing"; exit 1)

      - name: Upload build artifact
        uses: actions/upload-artifact@v4
        with:
          name: site-dist
          path: dist
          retention-days: 7
          if-no-files-found: error

  deploy:
    name: Deploy to Cloudflare Pages (${{ github.ref_name }})
    needs: build
    if: github.event_name == 'push'
    runs-on: ubuntu-latest
    timeout-minutes: 10
    permissions:
      contents: read
      deployments: write
    environment:
      name: ${{ github.ref_name == 'main' && 'production' || 'staging' }}
      url: ${{ steps.cf.outputs.deployment-url }}
    steps:
      - name: Download build artifact
        uses: actions/download-artifact@v4
        with:
          name: site-dist
          path: dist

      - name: Deploy via Wrangler
        id: cf
        uses: cloudflare/wrangler-action@v3
        with:
          apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          wranglerVersion: "4"
          command: deploy --env ${{ github.ref_name == 'main' && 'production' || 'staging' }} --name ${{ github.ref_name == 'main' && 'mhamza-space' || 'mhamza-space-staging' }}
```

That's it. Two jobs. One YAML file. Let's go through it section by section.

---

## Header — `name` and `on`

```yaml
name: CI/CD

on:
  push:
    branches: [main, staging]
  pull_request:
    branches: [main, staging]
```

**`name`** is the display name in the GitHub Actions UI. Calling this workflow "CI/CD" is honest — it does both continuous integration (build + lint on every change) and continuous deployment (push to live on merge to `main`/`staging`).

**`on:`** declares the triggers. This workflow runs on:

- A `push` event to either `main` or `staging`. This is what happens *after* a PR merge — the merge commit lands on the base branch, triggering a push event.
- A `pull_request` event targeting `main` or `staging`. This fires when a PR is opened, when new commits are pushed to its branch, or when its base branch changes.

Topic branches (`post/...`, `feature/...`, `fix/...`, etc.) don't trigger the workflow directly. They only trigger it indirectly, through the PR they're attached to. This keeps the Actions tab clean — only meaningful events show up.

### Why both `push` and `pull_request`?

You might think `pull_request` is enough — every change goes through a PR, right? But once the PR is merged, the resulting merge commit on `main`/`staging` is a `push` event, not a `pull_request` event. We need the workflow to fire on that push to trigger the deploy.

Conversely, why not just `push`? Because we want the build + lint to validate the PR *before* it's merged. The `pull_request` trigger gives the PR author a green / red check next to "All checks have passed" without needing to merge first.

The two triggers are not redundant — they cover two different moments in the change's lifecycle.

---

## `concurrency` — preventing wasted runs and broken deploys

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}
```

**`concurrency.group`** assigns every workflow run to a named group. Only one run per group can be active at a time. The group is `<workflow-name>-<git-ref>`. So a push to `staging` and a push to `main` are in different groups (they don't interfere). But two consecutive pushes to `staging` *are* in the same group.

**`cancel-in-progress`** is a conditional:

- For `pull_request` events: `true` — if you push three commits to a PR branch in quick succession, the first two runs get cancelled when the third one starts. Saves CI minutes and gives faster feedback.
- For `push` events: `false` — if you merge two PRs back-to-back, neither deploy gets cancelled. We let both runs complete. The second one's deploy overwrites the first one's, which is the intended behaviour.

The asymmetry — *cancel PR runs, queue prod runs* — is deliberate. PRs are throwaway compute; production deploys are not.

---

## `jobs.build` — the CI half

```yaml
build:
  name: Build & Lint
  runs-on: ubuntu-latest
  timeout-minutes: 10
  steps:
    ...
```

**`runs-on: ubuntu-latest`** — runs on a fresh Ubuntu VM provisioned by GitHub. Each run is a clean machine. The VM has Node, pnpm, Git, common tools pre-installed, but our workflow doesn't rely on those defaults — we install our own pinned versions.

**`timeout-minutes: 10`** — a safety net. If a step hangs or runs unexpectedly long, the whole job is killed after 10 minutes. In practice the job takes ~30 seconds; 10 minutes is a generous ceiling.

### Step: Checkout

```yaml
- name: Checkout
  uses: actions/checkout@v4
```

`actions/checkout@v4` is GitHub's official action to clone the repo into the workspace. The `@v4` is a major-version tag — it auto-tracks the latest 4.x release of the action.

For PRs from forks (which we don't have, since this is a personal repo), this action handles the trickier "merge commit" preview check-out. For our case it just does a shallow clone of the branch.

### Step: Set up pnpm

```yaml
- name: Set up pnpm
  uses: pnpm/action-setup@v4
  with:
    version: 10.27.0
    run_install: false
```

`pnpm/action-setup@v4` installs a specific pnpm version. We pin to **`10.27.0`** — matching the `packageManager` field in `package.json` exactly. Pinning prevents "pnpm has a minor bump and the lockfile format changed" from being a CI failure.

**`run_install: false`** is important. By default this action also runs `pnpm install` for you. We don't want that — we want Node + cache to be set up first, *then* install, so the cache works. So we tell the action "just install pnpm, don't actually install dependencies".

### Step: Set up Node

```yaml
- name: Set up Node
  uses: actions/setup-node@v4
  with:
    node-version: 22
    cache: pnpm
```

`actions/setup-node@v4` installs the requested Node version. We pin **Node 22** because:

- Astro 6 requires `>= 22.12`. Earlier than that and the build fails immediately with a clear "Node X is not supported" error.
- Node 22 is the current LTS line ("Jod"). Stable, security-patched, will receive updates through 2027.
- Locally Hamza is on Node 24. Matching 22 in CI means we test against the older floor — if the site builds on 22 it builds on 24, but not necessarily vice versa.

**`cache: pnpm`** tells the action to cache pnpm's package store between runs, keyed on `pnpm-lock.yaml`'s hash. On a cold first run this is a no-op; on subsequent runs (with the same lockfile) the cache restore takes seconds and `pnpm install` is much faster.

### Step: Install dependencies

```yaml
- name: Install dependencies
  run: pnpm install --frozen-lockfile
```

**`--frozen-lockfile`** is the CI-only flag. It says: "the lockfile must exactly match `package.json`. If `package.json` declares a dependency the lockfile doesn't pin, fail. Don't update the lockfile." This prevents the dreaded "works on my machine but the lockfile drifted in CI" failure mode.

Locally you run `pnpm install` (no `--frozen-lockfile`), which is allowed to update the lockfile when you add a new dependency. In CI, the expectation is "the lockfile is the source of truth; install must match it byte-for-byte".

### Step: Lint

```yaml
- name: Lint (Biome)
  run: pnpm lint
```

`pnpm lint` runs `biome check .` (defined in `package.json` scripts). Biome is the all-in-one linter + formatter we use instead of ESLint + Prettier. The rules are in `biome.jsonc`.

If a contributor commits unformatted or non-conforming code, this step fails the build. The fix is local: run `pnpm lint:fix` to auto-fix, commit, push.

The `.astro` files have many rules disabled because Astro's frontmatter compiler produces transient code that looks "wrong" to a regular TypeScript linter. That carve-out is in `biome.jsonc`.

### Step: Build

```yaml
- name: Build (Astro + Pagefind index)
  run: pnpm build
```

`pnpm build` runs `astro build`, which:

1. Validates every content collection against its schema.
2. Generates HTML for every page in `src/pages/`.
3. Processes every referenced image through Sharp.
4. Generates `dist/sitemap-index.xml` + `dist/sitemap-0.xml`.

Then `postbuild` (also defined in `package.json` scripts) runs `pagefind --site dist`, which crawls `dist/*.html` for `data-pagefind-body` regions and builds the search index into `dist/pagefind/`.

After this step, `dist/` is a complete static site ready for deploy.

### Step: Verify Pagefind index exists

```yaml
- name: Verify Pagefind index exists
  run: test -d dist/pagefind && echo "OK" || (echo "Pagefind index missing"; exit 1)
```

This is a paranoia check. Pagefind has been known to silently no-op if it can't find any `data-pagefind-body` elements. The `test -d` checks the directory exists; the `|| (... exit 1)` makes the step fail loudly if the index is missing.

Without this check, the build job would pass even when search was broken — and we'd only find out by manually testing search on the deployed site. With this check, search-broken = CI-red.

### Step: Upload build artifact

```yaml
- name: Upload build artifact
  uses: actions/upload-artifact@v4
  with:
    name: site-dist
    path: dist
    retention-days: 7
    if-no-files-found: error
```

`actions/upload-artifact@v4` zips up `dist/` and stores it on GitHub's artifact storage. The artifact is named `site-dist` — that's how the `deploy` job will reference it.

**`retention-days: 7`** — artifacts auto-delete after 7 days. We don't need to keep build artifacts forever; if we need to redeploy an old version, we re-run the workflow from a tag.

**`if-no-files-found: error`** — fail loudly if `dist/` is somehow empty. Same paranoia as the Pagefind check.

---

## `jobs.deploy` — the CD half

```yaml
deploy:
  name: Deploy to Cloudflare Pages (${{ github.ref_name }})
  needs: build
  if: github.event_name == 'push'
  runs-on: ubuntu-latest
  timeout-minutes: 10
  permissions:
    contents: read
    deployments: write
  environment:
    name: ${{ github.ref_name == 'main' && 'production' || 'staging' }}
    url: ${{ steps.cf.outputs.deployment-url }}
  steps:
    ...
```

### Job name interpolation

`name: Deploy to Cloudflare Pages (${{ github.ref_name }})` — yes, the name says "Pages" even though we deploy to Workers. That's a minor doc-vs-code drift; the deploy command does the right thing, but the display name could be updated to "Cloudflare Workers". Worth a future doc cleanup.

`${{ github.ref_name }}` expands to `main` or `staging` — the branch that triggered the workflow. So a run from staging shows up in the UI as "Deploy to Cloudflare Pages (staging)".

### `needs: build`

This job won't start until the `build` job has succeeded. If `build` fails, `deploy` is automatically skipped. There's no condition where a broken build gets deployed.

### `if: github.event_name == 'push'`

The deploy job only runs on `push` events — i.e. after a PR has merged. On `pull_request` events (PR opened / updated), the build job runs but deploy is skipped.

This is intentional: PRs should not auto-deploy anywhere. We rely on the staging-branch flow for previews. Hamza wanted *deliberate* production deploys, not accidental ones.

(Some teams set up PR previews by deploying every PR to a temporary URL. That's possible to add later — `cloudflare/wrangler-action` supports it — but for now we go with: staging-branch preview is enough.)

### `permissions:`

```yaml
permissions:
  contents: read
  deployments: write
```

GitHub's default workflow token can do more than this job needs. We narrow it down to the minimum:

- `contents: read` — clone the repo (which `actions/checkout` needs).
- `deployments: write` — write deployment status to GitHub's Deployments API, which powers the Environments tab.

Anything else (issues, packages, pull requests, etc.) is denied. Principle of least privilege.

### `environment:`

```yaml
environment:
  name: ${{ github.ref_name == 'main' && 'production' || 'staging' }}
  url: ${{ steps.cf.outputs.deployment-url }}
```

**GitHub Environments** are logical deploy targets visible on the repo's "Environments" tab. We have two: `production` and `staging`. The conditional picks the right one based on the branch.

**`url:`** points at the live URL of the deployment. `${{ steps.cf.outputs.deployment-url }}` reads an output from the Wrangler step (named `cf`). The Environments tab will display this URL with a "View deployment" link.

This is purely cosmetic but useful — when you look at the repo on GitHub, you see "Active deployments: production = mhamza.space, staging = staging.mhamza.space" with links.

Environments also support **protection rules** (required reviewers, wait timers, deployment branch restrictions). We're not using protection rules today; for a personal solo project they'd be overhead. But the option is there if we ever want, e.g., "production deploys require a 5-minute wait before they take effect".

### Step: Download build artifact

```yaml
- name: Download build artifact
  uses: actions/download-artifact@v4
  with:
    name: site-dist
    path: dist
```

The counterpart of the upload from the build job. Restores `dist/` from the artifact named `site-dist`. After this step, the deploy job's working directory has `dist/` populated with the exact bytes the build job produced.

**Why bother with an artifact instead of rebuilding?** Two reasons:

1. Determinism — the deploy is guaranteed to ship the exact bytes that the build job validated. No risk of "rebuild produced subtly different output because of timestamps or env differences".
2. Speed — avoids a redundant ~20-second build.

### Step: Deploy via Wrangler

```yaml
- name: Deploy via Wrangler
  id: cf
  uses: cloudflare/wrangler-action@v3
  with:
    apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
    accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
    wranglerVersion: "4"
    command: deploy --env ${{ github.ref_name == 'main' && 'production' || 'staging' }} --name ${{ github.ref_name == 'main' && 'mhamza-space' || 'mhamza-space-staging' }}
```

The most subtle step in the file. Let's go through it carefully.

**`id: cf`** lets later steps (and the `environment.url`) reference this step's outputs as `steps.cf.outputs.<name>`. The Wrangler action emits a `deployment-url` output containing the deployed Worker URL.

**`uses: cloudflare/wrangler-action@v3`** — Cloudflare's official wrapper action. Internally it installs Wrangler and runs the configured command.

**`apiToken:`** — the Cloudflare API token. Stored as a GitHub repo secret. Scope: `Account → Workers Scripts → Edit`.

**`accountId:`** — the Cloudflare account ID. Stored as a secret too (not because it's secret-secret, but to keep it out of the YAML and easy to rotate).

**`wranglerVersion: "4"`** — without this, the action installs Wrangler 3.x by default. Wrangler 3 doesn't fully support static-asset Workers (the `[assets]` directive). We force version 4. This pin was added in PR #3 after the first Wrangler-3-based deploy failed with:

```
No environment found in configuration with name "staging".
Missing entry-point: ...
```

**`command:`** — the actual Wrangler invocation. Let's expand the templating:

```
For ref_name = "main":
    deploy --env production --name mhamza-space

For ref_name = "staging":
    deploy --env staging --name mhamza-space-staging
```

- `--env <env>` tells Wrangler which environment block in `wrangler.toml` to use.
- `--name <name>` *forces* the deployed Worker's name to the given string, overriding `wrangler.toml`'s `[env.<name>].name`. This pin was added in PR #5 after the previous deploy produced a Worker named `kb-blogs-staging` instead of `mhamza-space-staging` — Cloudflare's name resolution was somehow influenced by pre-existing project context on the account. The CLI flag is bulletproof.

After this step, the Worker is updated and serving the new content. Cloudflare's edge propagates the change globally within seconds.

---

## What you see when the workflow runs

### On PR open / update

1. GitHub Actions queues a `pull_request` event run.
2. `build` job starts. Status badge on the PR turns yellow (running).
3. `build` runs all its steps: checkout, pnpm, Node, install, lint, build, Pagefind verify, upload.
4. If any step fails: badge turns red. The PR can still be merged (we don't have branch protection rules), but you really shouldn't.
5. If all pass: badge turns green ✅. PR is mergeable.
6. `deploy` job is skipped because of the `if:` condition.

### On PR merge (push to main/staging)

1. Merging the PR creates a merge commit on the base branch.
2. That commit triggers a `push` event.
3. `build` job runs again (yes, the same code; the cost is one redundant build, ~30s).
4. After `build` passes, `deploy` job starts.
5. `deploy` downloads the artifact, runs Wrangler, posts the deployment URL.
6. The Environments tab updates with the new active deployment.

Total wall-clock time for a typical run: 60-90 seconds.

---

## Secrets management

Two secrets in repo settings (Settings → Secrets and variables → Actions):

| Secret | Source | Used in |
|---|---|---|
| `CLOUDFLARE_API_TOKEN` | Cloudflare dashboard → My Profile → API Tokens → Create Token (Custom: Workers Scripts: Edit + Account Settings: Read) | Wrangler step |
| `CLOUDFLARE_ACCOUNT_ID` | Visible in any Cloudflare URL: `dash.cloudflare.com/<id>/...` | Wrangler step |

Both are scoped to the repo — they're not available to other repos in the org / on the account. They're encrypted at rest in GitHub's secret store. They're *not* visible to PR runs from forks (which we don't have), so a malicious PR can't exfiltrate them.

### Rotating the API token

If the token leaks or you want a periodic rotation:

1. Cloudflare dashboard → My Profile → API Tokens → find the token → **Roll** (Cloudflare's term for "regenerate").
2. Copy the new token value (shown only once).
3. GitHub: Settings → Secrets and variables → Actions → `CLOUDFLARE_API_TOKEN` → **Update**. Paste the new value.
4. Old token is invalidated automatically by Cloudflare. Next workflow run uses the new one.

No code change required. Zero downtime.

---

## The three pinned versions (and why each matters)

| Pin | Value | Consequence if missing |
|---|---|---|
| `actions/setup-node@v4 node-version` | `22` | Build fails immediately on Node 20 with "Astro 6 requires Node ≥22.12". |
| `pnpm/action-setup@v4 version` | `10.27.0` | Mismatch with the local `packageManager` field; pnpm might be a different minor; lockfile format edge cases possible. |
| `cloudflare/wrangler-action@v3 wranglerVersion` | `"4"` | Deploy fails with "No environment found ... Missing entry-point" because Wrangler 3 doesn't fully support static-asset Workers. |

The three pins together are the cumulative knowledge from three deploy failures. Each pin is one less thing that can drift unexpectedly.

---

## What's *not* in this pipeline (yet)

Things you might wonder why we don't have, and the answer:

| Missing | Why not (today) |
|---|---|
| Type-check step (`pnpm astro check`) | Could be added as a step after lint. Currently relying on TS strictness + IDE feedback. Trivial to add when needed. |
| Bundle size / Lighthouse audit | Useful for performance-critical sites; this site is light. Add via `treosh/lighthouse-ci-action` later if needed. |
| Security scan | The site has zero JavaScript in the runtime (static), so the attack surface is tiny. Worth adding a `npm audit` / `pnpm audit` step in the future. |
| Notification on failure | Could `Slack`-notify, email, etc. For a solo project, the GitHub Actions tab + the email GitHub sends on failures is enough. |
| Per-PR preview deploys | Possible with extra Wrangler config; for now the `staging` branch *is* the preview. |
| Auto-changelog generation | Could parse conventional commit messages and emit Markdown. Currently maintained by hand because the volume is low. |

None of these are blockers. They're all additions to consider if usage scales or if the project becomes multi-contributor.

---

## When things go wrong

See [08 — Troubleshooting](./08-troubleshooting.md) for specific failure modes and their diagnoses. The high-level rule: **read the logs**. GitHub Actions logs are searchable, downloadable, and persistent. Every error message we hit in development is now captured in `docs/runbooks/deploy-cloudflare-pages.md` → "Notes during initial setup". If you hit a new error, add it.

---

Next: [06 — Daily workflows](./06-daily-workflows.md)
