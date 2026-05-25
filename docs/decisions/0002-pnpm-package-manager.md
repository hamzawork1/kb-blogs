# ADR 0002 — Use pnpm as the package manager

- **Status:** Accepted
- **Date:** 2026-05-25
- **Deciders:** Muhammad Hamza

## Context

The repo is a **pnpm workspace** by design: the root is the Astro site, and
`package/` is a sibling workspace package that publishes the local `spectre`
integration (see `pnpm-workspace.yaml` and the `packageManager` field in
`package.json`).

Early in setup, `npm install` was run accidentally, which produced a
`package-lock.json` alongside the existing `pnpm-lock.yaml`. Having two
lockfiles is a source of non-determinism: different tools (CI, hosting
providers, local devs) may pick different ones.

## Decision

Use **pnpm 10.27.0** (pinned via the `packageManager` field) exclusively.

- `pnpm-lock.yaml` is the only committed lockfile.
- `package-lock.json` is deleted and must not be regenerated.
- `corepack` is the recommended way to get pnpm without polluting the global
  npm prefix — but `npm install -g pnpm@10.27.0` is fine as a fallback on
  systems where corepack lacks permissions (Windows + Program Files).

## Alternatives considered

| Option | Pros | Cons | Verdict |
|---|---|---|---|
| **pnpm** (chosen) | Faster than npm; ~70% less disk via content-addressable store + hard links; strict dependency resolution catches phantom-dep bugs; first-class workspace support — already configured in this repo. | Slightly steeper learning curve than npm for newcomers. | ✅ Selected |
| npm | Default with Node; familiar. | No workspace-grade features (without extra tooling); fatter `node_modules`; slower installs; permits phantom dependencies. | Rejected |
| yarn (Classic / Berry) | Mature; PnP mode is interesting. | Adds tooling without a clear benefit over pnpm here; Berry's PnP requires per-tool support. | Rejected |
| bun | Very fast install; native TS/JSX runtime. | Astro ecosystem is npm/pnpm-first; less battle-tested for production builds on Cloudflare Pages today. | Rejected |

## Consequences

- Cloudflare Pages auto-detects the lockfile and uses pnpm automatically.
  (If override is ever needed: set `PACKAGE_MANAGER=pnpm` in Pages env vars.)
- New devs / fresh clones must use pnpm:
  ```powershell
  corepack enable                  # if it works on your machine
  # or:
  npm install -g pnpm@10.27.0      # fallback (Windows / no admin)
  pnpm install
  ```
- The README's "Quick start" should reference `pnpm <script>`, not
  `npm run <script>`.
- All CI/automation must invoke pnpm explicitly.

## Reversibility

Switching back to npm would mean:

1. Delete `pnpm-lock.yaml` and `pnpm-workspace.yaml`.
2. Remove the `packageManager` field from `package.json`.
3. Rework `package/` integration as a relative file dependency
   (`"file:./package"`) instead of a workspace package.
4. Run `npm install` to generate `package-lock.json`.

That's a non-trivial change, so it would warrant its own ADR.
