# 01 — Overview

## What this project is

**mhamza.space** is a personal portfolio and tech blog for Muhammad Hamza (Azure Cloud Specialist & DevOps Engineer). It serves a single technical audience: peers who want to read field-tested notes on Azure, DevOps, Kubernetes, Terraform, and adjacent topics.

The site is intentionally:

- **Fully static** — every page is pre-built HTML/CSS/JS. No databases. No per-request server code. No user accounts.
- **Edge-hosted** — Cloudflare's global network serves bytes from the nearest data centre to each visitor.
- **Git-driven** — every change to the site is a commit in `hamzawork1/kb-blogs`. There is no CMS, no separate content store. The repository *is* the site.
- **Pipeline-deployed** — pushing to `staging` or `main` triggers a GitHub Actions run that builds and deploys. There is no manual deploy step.

The model is: **write Markdown → push → site updates**. Everything else is plumbing that's already in place.

---

## Tech stack at a glance

```
                          You
                           |
                           | git push
                           v
                  +-------------------+
                  | hamzawork1/kb-blogs|   GitHub
                  +-------------------+
                           |
                           | on push to main/staging
                           v
                  +-------------------+
                  |   GitHub Actions  |   CI/CD
                  |    ci-cd.yml      |
                  |  - build job      |
                  |  - deploy job     |
                  +-------------------+
                           |
                           | wrangler deploy --env <env>
                           v
                  +-------------------+
                  | Cloudflare Workers|   Edge host
                  |  (static assets)  |
                  +-------------------+
                           |
                           | HTTPS over Cloudflare's CDN
                           v
                       Your readers
```

| Layer | Tool | Why |
|---|---|---|
| Site generator | **Astro 6** | Content-first SSG with Markdown / MDX + content collections + zero-JS by default |
| Theme | **Spectre** (customised) | Terminal-inspired dark theme that ships search, OG, and good defaults |
| Theme integration | Local workspace package (`package/`) | Custom Astro integration exposing `spectre:globals` virtual module |
| Search | **Pagefind 1.5** | Static, build-time index. No server needed. |
| Content format | **MDX** | Markdown + JSX for embedded components when needed |
| Styling | Plain CSS + Expressive Code | No Tailwind. Code highlighting via Shiki under Expressive Code. |
| Type-check | **TypeScript 5.9** | Astro understands TS natively. Schemas in `content.config.ts` are Zod. |
| Lint / format | **Biome 2.4** | Single tool for both, tabs + double quotes enforced |
| Package manager | **pnpm 10.27** | Workspace-native, fast, disk-efficient |
| CI / CD | **GitHub Actions** | Free-tier-fine pipeline; full control unlike Cloudflare's native Git deploy |
| Wrangler CLI | **Wrangler 4** | Required for static-asset Workers' `[assets]` directive |
| Host | **Cloudflare Workers + static assets** | Modern successor to Cloudflare Pages; edge-native |
| DNS / CDN | **Cloudflare DNS** (already on the account) | Same dashboard, integrates with Workers |
| Comments | Giscus (disabled for now) | GitHub Discussions-backed comments when re-enabled |

---

## Operating model

There are exactly two long-lived branches:

- **`main`** — production. Whatever sits on `main` is what `mhamza.space` serves.
- **`staging`** — pre-production. Whatever sits on `staging` is what `staging.mhamza.space` serves.

All real work happens on short-lived topic branches, named by intent:

- `post/<slug>` — adds a new blog post
- `feature/<name>` — adds or changes a site feature
- `fix/<name>` — fixes a bug
- `docs/<name>` — docs-only changes
- `ci/<name>` — pipeline-only changes
- `chore/<name>` — housekeeping (deps, lockfile, gitignore)

A change reaches production via this chain:

```
topic branch  ─PR─►  staging  ─PR─►  main
                       │              │
                       deploys to    deploys to
                       staging.      mhamza.space
                       mhamza.space  (production)
                       (preview)
```

No commits are pushed directly to `main`. No commits are pushed directly to `staging` either — everything goes through a pull request, even for solo work. The friction of "one extra step" is the point — it forces you to look at the diff one more time before it goes live.

Why this model fits a solo personal site:

1. Every change has a PR description telling future-you what and why.
2. CI runs `lint + build` automatically on every PR — broken code never lands.
3. Cloudflare's preview at `staging.mhamza.space` lets you verify visually before a production push.
4. Rolling back is "revert the merge commit, push" — never frantic.

---

## What you'll need installed locally

- **Node 22+** (Astro 6 requires ≥22.12; locally you can run 22 or 24)
- **pnpm 10.27** (via `corepack enable` or `npm install -g pnpm@10.27.0`)
- **Git**
- **GitHub CLI (`gh`)** — for opening PRs without clicking around in the browser
- **PowerShell** or any terminal — examples in this kit use PowerShell on Windows, but everything is portable

That's it. No Docker, no databases, no local Cloudflare emulator. Astro's dev server + Pagefind are the only runtimes that matter.

---

## What this kit will and won't teach you

**Will:**
- Why every choice in this project was made.
- How the pieces fit together.
- How to perform every common task without re-reading random tutorials.
- How to debug the most common failures.
- How to migrate parts of the stack if you ever want to (each ADR has a reversibility section).

**Won't:**
- Be a beginner programming course. We assume you can read TypeScript, write Markdown, and use Git.
- Replicate full documentation for Astro / Cloudflare / pnpm — those are linked when relevant, not paraphrased.

**When in doubt, the rule is:** if the answer is in this kit, you should be able to find it. If it isn't, the linked external docs cover it. If neither, open an issue against yourself in the repo.

---

Next: [02 — Tooling primer](./02-tooling-primer.md)
