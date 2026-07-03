# ADR 0004 — Pipeline modernization (DevSecOps hardening)

**Status:** Accepted · **Date:** 2026-05-25 · **Supersedes parts of:** [ADR 0003](0003-github-actions-deploy.md) (deploy mechanism untouched; quality gates and security posture extended)

## Context

ADR 0003 established the baseline pipeline: a two-job workflow (`build` → `deploy`) shipping the Astro static output to Cloudflare Workers via `cloudflare/wrangler-action@v3` pinned to Wrangler 4. It worked. But "it works" is the floor, not the ceiling — by modern DevSecOps standards the pipeline skipped entire categories of guardrails:

- No type / content-schema checking (`astro check`) — schema breaks reach `dist/`.
- No Software Composition Analysis — vulnerable dependencies pass through silently.
- No secret scanning — a leaked Cloudflare token in a commit has nothing watching for it.
- No Software Bill of Materials — no record of what shipped.
- No provenance attestation — no cryptographic chain of custody on the artifact.
- No performance budgets — a 5 MB hero image regresses without anyone noticing.
- No link auditing — relative refs in posts rot silently; external links die between releases.
- No post-deploy verification — Wrangler returning success ≠ the site rendering.
- No commit / PR discipline enforcement — Conventional Commits were a convention, not a gate.
- Every commit re-ran the full pipeline regardless of whether it touched anything that built into `dist/` — wasted minutes and noise.
- Third-party actions tag-pinned (`@v4`) — a tag re-point on a compromised maintainer's account would silently swap in malicious code.

## Decision

Modernize the pipeline as a parallel-DAG **Pipeline-as-Code** layout, layering DevSecOps controls across the build and deploy phases. Every tool is open-source and operates within free tiers (the repo is public — GitHub Actions minutes are unlimited; Renovate via Mend's OSS hosting is free; `actions/attest-build-provenance` and `step-security/harden-runner` audit mode are free for public repos).

### Pipeline topology

```
Trigger plane:  push (main|staging) | pull_request | workflow_dispatch | schedule (security cron)
                paths-ignore: docs/, *.md root, .vscode/, .claude/, etc.
                permissions: contents: read   (least-privilege default)
                concurrency: cancel-in-progress on PR events

Shift-left quality gates (parallel, ~30-45s):
  [Lint]          biome check
  [Typecheck]     astro check                       <- NEW (PR 1)
  [PR-title]      amannn semantic PR    (PR-only)   <- NEW (commit discipline)
  [Commitlint]    wagoid                (PR-only)   <- NEW (commit discipline)
                                |
                                v
                          [Build]                   <- attests SLSA L3 provenance on push
                                |
            +------------+------+------+-------------+
            v            v             v             v
      [Link-Check-PR] [Lighthouse]  [Deploy]     (push-only)
      (offline,        (perf+a11y     |
       internal refs)   warn->error)  v
                                  [Smoke]          <- NEW (synthetic GET)
                                  [Link-Check-Live] (push to staging only)

Separate workflows (off the critical path):
  security.yml          - gitleaks + osv-scanner + CycloneDX SBOM (PR + push + Monday cron)
  link-check-cron.yml   - weekly live link audit independent of deploys
```

### Open-source, free-tier toolchain

| Layer | Tool | License |
|---|---|---|
| Type / content schema | `astro check` via `@astrojs/check` | MIT |
| Performance / a11y / SEO budgets | Lighthouse CI + `treosh/lighthouse-ci-action` | Apache-2.0 |
| Link auditing (offline + live + cron) | Lychee + `lycheeverse/lychee-action` | Apache-2.0 / MIT |
| Synthetic post-deploy smoke | Node's built-in `fetch` (`scripts/smoke.mjs`, ~30 LOC, zero deps) | MIT (this repo) |
| Secret scanning (deep history) | `gitleaks/gitleaks-action` | MIT |
| SCA (CVE scan of `pnpm-lock.yaml`) | Google's `osv-scanner-action` | Apache-2.0 |
| SBOM (CycloneDX) | Anchore's Syft via `sbom-action` | Apache-2.0 |
| Provenance (SLSA Level 3) | `actions/attest-build-provenance` | MIT (GitHub-maintained) |
| Runner hardening (egress audit) | `step-security/harden-runner` | Apache-2.0 |
| PR title check | `amannn/action-semantic-pull-request` | MIT |
| Per-commit lint | `wagoid/commitlint-github-action` | MIT |
| Dependency lifecycle | Renovate via Mend free OSS hosting | AGPL-3.0 |

### Supply-chain hardening

- **Third-party actions are SHA-pinned**, not tag-pinned. Pins carry a trailing `# v<tag>` comment for readability. Renovate (`pinDigests: true` in `renovate.json`) keeps them fresh.
- **First-party `actions/*` stay tag-pinned at major** (`@v4`). GitHub-owned; supply-chain risk ≈ GitHub-itself, and SHA-pinning these creates noise without buying real defence.
- **`step-security/harden-runner` runs as the first step of every job** in audit mode. Logs egress; doesn't block. Surfaces in the job summary.

### Skip list (deliberate non-goals)

- **CodeQL** — Code-level SAST on a static-only Astro site is theatre. No user-input → server boundary, no SSR, no APIs. Secret-scan + SCA cover the actual surface.
- **Semgrep** — Same reasoning as CodeQL; rule-based SAST scanning Zod schemas + Spectre integration = noise > signal. Re-evaluate if the JS surface grows (comments backend, API routes, etc.).
- **`workflow_run`-split deploy pipeline** — `needs:` DAG in a single workflow is faster, more debuggable, and lets CI iterate on PRs.
- **Dependabot** — Renovate covers the same ground with better grouping and `pinDigests` for SHA maintenance.
- **PR preview deploys** — Staging branch is the pre-production environment.
- **`release-please` / changesets** — Not a published artifact; manual `CHANGELOG.md` (Keep-a-Changelog) is the right tool.
- **Probot Settings / branch-protection-as-code** — Solo repo; GUI-configured once + ADR documentation is sufficient.
- **Playwright / Vitest / Jest** — Astro site is declarative content. Unit-test logic when there's logic worth isolating.
- **Container scanning (Trivy / Snyk)** — No containers in the stack.
- **OIDC for Cloudflare Wrangler** — Cloudflare API does not yet support GitHub OIDC tokens for Wrangler. Tracked; revisit annually. Long-lived scoped API token (`Workers Scripts:Edit`) is the only option today.
- **Self-hosted runners** — Free public-repo Actions minutes are unlimited.

### Production quality bar

The pipeline holds itself to the same standard the repo's code does:

- No hardcoded secrets — every credential is `${{ secrets.* }}`.
- No `pull_request_target` (untrusted PR code becomes a privileged context).
- No `[skip ci]` patterns.
- No `continue-on-error` on quality gates (exception: `audit`-style informational steps).
- Workflow root sets `permissions: contents: read`; jobs escalate explicitly when needed (e.g., `attestations: write` on build, `pull-requests: write` on Lighthouse).
- Workflow names, job names, step names are human-readable.

## Consequences

### Positive

- **Lead time stays low.** Parallel gates keep wall-clock CI at ~2:30 for the full DAG. `paths-ignore` skips docs-only commits entirely.
- **Change Failure Rate drops measurably.** Type-check / link-check / Lighthouse / smoke block dead-on-arrival regressions before they reach production.
- **Verifiable supply chain.** SLSA L3 provenance lets anyone `gh attestation verify` a build artifact. CycloneDX SBOM tracks what shipped.
- **Defence-in-depth.** Secret scanning catches token leaks; SCA catches vulnerable deps; harden-runner catches unexpected egress; SHA pins block tag re-point attacks.
- **Cost-free.** Every tool is open-source; the public repo plus free tiers cover everything (no Codecov / SonarCloud / Snyk / Datadog / Mend Enterprise).
- **Recognisable on a DevOps CV.** The terminology (DevSecOps, SLSA, SBOM, SAST, SCA, Pipeline-as-Code, Policy-as-Code, shift-left, continuous verification) is what enterprise teams ask about.

### Trade-offs

- **More moving parts.** Eight new workflow jobs + one new workflow file + a few config files. Renovate covers maintenance of action pins / dependency bumps, but the surface area is larger to reason about.
- **Lighthouse runs against the static `dist/`** — desktop preset, devtools throttling. Reflects "page weight + render efficiency", not real-world network conditions. Mobile coverage is an explicit future addition.
- **Lighthouse budgets ship as `warn` initially.** Lets the baseline emerge before hard-gating. Flip to `error` after ~3 successful runs.
- **External link checking is flaky by nature.** `link-check-live` runs only on staging push and on a weekly cron — it does NOT gate the production deploy.
- **OIDC for Cloudflare is still pending** upstream support. Until then, scoped long-lived tokens are the only option.
- **The plan's PR 9 (branch protection)** is GUI work — required-status-checks and required-reviewer-on-production-environment are configured in GitHub repo settings, not as code in this repo. Documented here for traceability.

## Alternatives considered

- **Tighten Biome to enforce more rules** — orthogonal; this ADR added new tools, not stricter lint configuration.
- **Snyk free tier instead of OSV-Scanner** — Snyk is freemium with usage caps; OSV-Scanner is unconditionally free for public repos and Google-maintained. Picked OSV.
- **Codecov for coverage tracking** — no tests yet, so the question is moot. Re-evaluate when test coverage exists.
- **GitHub Advanced Security (GHAS)** — code-scanning, secret-scanning, and Dependabot security alerts are free for public repos; we use the latter two (built-in secret-scanning + Renovate + Dependabot security alerts). CodeQL skipped per Skip list above.

## Reference

Pipeline file: [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml). Security workflow: [`.github/workflows/security.yml`](../../.github/workflows/security.yml). Link-check cron: [`.github/workflows/link-check-cron.yml`](../../.github/workflows/link-check-cron.yml). Composite setup: [`.github/actions/setup-node-pnpm/action.yml`](../../.github/actions/setup-node-pnpm/action.yml). Lychee config: [`../../lychee.toml`](../../lychee.toml). Lighthouse config: [`../../.lighthouserc.json`](../../.lighthouserc.json). Smoke: [`../../scripts/smoke.mjs`](../../scripts/smoke.mjs). Commitlint: [`../../commitlint.config.js`](../../commitlint.config.js). Dependency lifecycle: [`../../renovate.json`](../../renovate.json).
