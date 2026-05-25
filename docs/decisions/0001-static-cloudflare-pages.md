# ADR 0001 — Host on Cloudflare Pages as a fully static site

- **Status:** Accepted
- **Date:** 2026-05-23
- **Deciders:** Muhammad Hamza

## Context

The site is a personal portfolio + tech blog with:

- Content authored as Markdown / MDX, committed to Git.
- No user accounts, no databases, no per-request server logic.
- Search via [Pagefind](https://pagefind.app) — a *build-time* static index.
- Comments via [Giscus](https://giscus.app) — currently disabled, but it's a
  client-side embed when enabled (no server needed).

The original Spectre theme ships with the `@astrojs/node` SSR adapter
configured. SSR isn't needed and actively complicates hosting (requires a
Node runtime, container, or serverless wrapper).

## Decision

Build the site with `output: "static"` and **no Astro adapter**. Deploy as
plain HTML / CSS / JS to **Cloudflare Pages**.

## Alternatives considered

| Option | Pros | Cons | Verdict |
|---|---|---|---|
| **Cloudflare Pages** (chosen) | Free tier covers personal use; global edge CDN; automatic preview deploys per branch; native custom-domain + DNS in the same dashboard; Workers integration if SSR is needed later. | Less generous free-tier build minutes than Netlify (still ample). | ✅ Selected |
| Vercel | Best-in-class DX for Next.js; great preview deploys. | Bandwidth limits on free tier; team/usage tiers escalate fast; less appealing for purely static content. | Rejected |
| Netlify | Mature, simple, generous free tier. | Slower cold builds; harder to integrate with other Cloudflare infra (R2, Workers) we may add later. | Rejected |
| GitHub Pages | Free, zero-setup, integrates with the repo. | No preview deploys per branch; awkward custom-domain SSL renewal; no edge-level controls. | Rejected |
| Self-hosted (Node + reverse proxy on a VPS) | Full control. | Operational overhead disproportionate to a personal site; ongoing OS patching, TLS, etc. | Rejected |

## Consequences

- All routes must work via `getStaticPaths` (or be in `src/pages/` as static files).
- The Node `start` script and `@astrojs/node` dependency were removed (see
  `package.json` history).
- `src/pages/styles/giscus.ts` uses `export const prerender = true;` so the
  endpoint emits as a static asset at build time.
- `postbuild` runs `pagefind --site dist` (not `dist/client`) — there is no
  longer a `dist/client` / `dist/server` split.
- Deployment is purely "push to branch" — Cloudflare auto-builds. Branch
  strategy (`main` = prod, `staging` = preview) maps directly to Pages'
  production and preview deploys.

## Reversibility

If SSR becomes necessary later (e.g. authenticated content, dynamic OG images),
two main escape hatches:

1. Switch `output: "server"` and add the Cloudflare adapter
   (`@astrojs/cloudflare`) — Cloudflare Pages supports SSR via Workers.
2. Move to a different host (Vercel / fly.io / a VPS).

Neither requires code rewrites — only config changes.
