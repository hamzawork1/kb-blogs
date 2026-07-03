# mhamza.space

Personal site and tech blog of **Muhammad Hamza** — Azure Cloud Specialist & DevOps Engineer.

[![CI](https://github.com/hamzawork1/kb-blogs/actions/workflows/ci.yml/badge.svg)](https://github.com/hamzawork1/kb-blogs/actions/workflows/ci.yml)
[![Security](https://github.com/hamzawork1/kb-blogs/actions/workflows/security.yml/badge.svg)](https://github.com/hamzawork1/kb-blogs/actions/workflows/security.yml)
[![Deployed on Cloudflare Workers](https://img.shields.io/badge/deploy-cloudflare%20workers-F38020?logo=cloudflare&logoColor=white)](https://mhamza.space)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![SLSA Level 3](https://slsa.dev/images/gh-badge-level3.svg)](https://slsa.dev/spec/v1.0/levels#build-l3)

Source:  <https://github.com/hamzawork1/kb-blogs>
Staging: <https://staging.mhamza.space>
Live:    <https://mhamza.space> (not yet deployed — pending first push to `main`)

Built on [Astro](https://astro.build/) using a customised version of the
[Spectre](https://github.com/louisescher/spectre) theme. Deployed as a fully
static site to **Cloudflare Workers (with static assets)** via GitHub Actions.

---

## Quick start

This repo uses **pnpm** (workspace setup). Install pnpm via `corepack enable`
or `npm install -g pnpm@10.27.0`, then:

```powershell
# install deps (first time)
pnpm install

# dev server (no search, fast iteration)
pnpm dev

# production build + Pagefind search index
pnpm build

# preview the built output locally (search works here)
pnpm preview
```

| Script        | What it does |
|---------------|--------------|
| `dev`         | Local Astro dev server. Hot reload. Search is stubbed. |
| `build`       | Static build into `dist/`. Runs Pagefind afterwards via `postbuild`. |
| `preview`     | Serves `dist/` locally — use this to test search and OG images. |
| `lint`        | Biome check. |
| `lint:fix`    | Biome autofix. |

---

## Branch strategy

```
main          production         (mhamza.space)         protected, PR-only from staging
  |
  +-- staging  pre-production    (preview URL)          all merges land here first
        |
        +-- post/<slug>          a single blog post
        +-- feature/<name>       a new feature / theme change
        +-- fix/<name>           a bug fix
```

### Workflow for every change

1. `git checkout staging && git pull`
2. `git checkout -b post/<slug>` (or `feature/<name>`, `fix/<name>`, `chore/<name>`, `docs/<name>`, `ci/<name>`)
3. Make changes. Commit in small, focused commits (Conventional Commits — `commitlint` is enforced on PRs).
4. `git push -u origin <branch-name>`
5. Open a PR → **`staging`**. CI runs lint, typecheck, build, Lighthouse, link-check, secret-scan, SCA, SBOM, and provenance attestation. No PR preview URL — verify locally with `pnpm preview`, or merge to staging to see it at `staging.mhamza.space`.
6. Verify the preview, merge to `staging`.
7. Once `staging` is solid, open a PR `staging` → `main`. Merge to deploy live.

> Never push directly to `main`. All production deploys come through staging.

---

## Adding a blog post

1. **Create the post file** in [`src/content/posts/`](src/content/posts/).
   Filename = URL slug. Lowercase, hyphens, no spaces.
   ```
   src/content/posts/azure-vnet-peering-guide.mdx
   ```
   → URL: `mhamza.space/blog/azure-vnet-peering-guide`

2. **Add frontmatter** at the top:
   ```mdx
   ---
   title: "Your post title"
   description: "1–2 line summary for SEO and the blog card preview."
   image: "../assets/azure-cover.png"
   createdAt: 2026-05-23
   draft: false
   tags:
     - azure
     - devops
   ---
   ```

   | Field        | Required | Notes |
   |--------------|----------|-------|
   | `title`      | yes      | Browser tab + page heading. |
   | `description`| yes      | SEO + blog list preview. |
   | `image`      | yes      | Cover image. See **Image strategy** below. |
   | `createdAt`  | yes      | `YYYY-MM-DD`. |
   | `updatedAt`  | optional | Add when you edit a published post. |
   | `draft`      | optional | `true` to hide. Default `false`. |
   | `tags`       | yes      | Array. Tag IDs must exist in [`src/content/tags.json`](src/content/tags.json). |

3. **Write the body** below the frontmatter — standard Markdown + MDX. Syntax
   highlighting via Expressive Code.

4. **New tag?** Add it to [`src/content/tags.json`](src/content/tags.json) first, then run
   `pwsh scripts/generate-covers.ps1 -Tag <tag>` (after adding a palette entry
   for it in the script). Otherwise the build will fail with a reference error.

---

## Image strategy

### Cover images — reusable per-tag banners

Every post needs a cover image (enforced by the schema). To avoid uploading a
unique image per post, the site uses **one cover banner per tag**. They live in
[`src/content/assets/`](src/content/assets/):

```
src/content/assets/
  azure-cover.png       # for posts tagged "azure"
  devops-cover.png      # for posts tagged "devops"
  kubernetes-cover.png
  terraform-cover.png
  ci-cd-cover.png
  notes-cover.png
  guide-cover.png
```

In a post's frontmatter, just reference the relevant tag's banner:

```mdx
image: "../assets/azure-cover.png"
```

#### Regenerating banners

Banners are generated by [`scripts/generate-covers.ps1`](scripts/generate-covers.ps1).
Re-run it any time you want to tweak colours or add a new tag banner:

```powershell
# Regenerate all banners
pwsh scripts/generate-covers.ps1

# Regenerate only one
pwsh scripts/generate-covers.ps1 -Tag azure
```

To add a banner for a new tag, edit the `$Palettes` hash table at the top of the
script and re-run with `-Tag <new-tag>`.

### In-post images (screenshots, diagrams)

For images that appear inside a post's body (e.g. Azure portal screenshots):

1. Drop the file in `src/content/assets/` next to the cover banners. Use a name
   that includes the post slug: `azure-vnet-peering-step-3.png`.
2. Reference it in the MDX body with a relative path:
   ```mdx
   ![Step 3 — verify peering status](../assets/azure-vnet-peering-step-3.png)
   ```
3. Keep each image under **500 KB**. PNG for screenshots, JPG/WebP for photos.
   Astro's image pipeline will optimise output further at build time.

> If the asset folder gets large (>20 MB total), switch cover banners to an
> external CDN (Cloudflare R2 with a custom subdomain like `cdn.mhamza.space`).
> Schema change required: `image: z.string().url()` in
> [`src/content.config.ts`](src/content.config.ts).

---

## Project layout

```
.
+- astro.config.ts              # site config, integrations, OG meta
+- package.json
+- src/
|  +- assets/pfp.png            # profile picture (replace with your own)
|  +- content.config.ts         # collection schemas (posts, projects, etc.)
|  +- content/
|  |  +- info.json              # "Quick info" pills on the home page
|  |  +- socials.json           # social links on the home page
|  |  +- tags.json              # tag IDs allowed in post frontmatter
|  |  +- work.json              # work experience list
|  |  +- other/about.mdx        # "About me" block on the home page
|  |  +- posts/                 # blog posts (one .mdx per post)
|  |  +- projects/              # project showcases
|  |  +- assets/                # cover banners + in-post images
|  +- pages/                    # routes
|  +- components/               # Astro components
|  +- layouts/Layout.astro
|  +- styles/                   # global + article CSS
+- package/                     # the customised Spectre integration source
+- scripts/
|  +- generate-covers.ps1       # regenerate tag cover banners
```

---

## Deployment — Cloudflare Workers (static assets) via GitHub Actions

The site builds to fully-static HTML and is deployed as a Cloudflare
**Worker with static assets** (the modern successor to Pages). Deploys are
driven by [`.github/workflows/ci.yml`](.github/workflows/ci.yml),
not by Cloudflare's native Git integration.

- **Production** — push to `main` → Worker `mhamza-space-prod` → custom domain
  `blog.mhamza.space`.
- **Staging** — push to `staging` → Worker `mhamza-space-staging` → optional
  `staging.mhamza.space`.
- **Build environment** — Node 22 (Astro 6 requires `>= 22.12`), pnpm 10.27.
- **Asset config** — declared in [`wrangler.toml`](wrangler.toml).
- **Required GitHub secrets** — `CLOUDFLARE_API_TOKEN` (scope
  `Workers Scripts:Edit`), `CLOUDFLARE_ACCOUNT_ID`.

Full step-by-step setup, rollback, and troubleshooting live in
[`docs/runbooks/deploy-cloudflare-pages.md`](docs/runbooks/deploy-cloudflare-pages.md).
Rationale is in [ADR 0001](docs/decisions/0001-static-cloudflare-pages.md)
and [ADR 0003](docs/decisions/0003-github-actions-deploy.md).

---

## Comments (Giscus)

Comments are powered by [Giscus](https://giscus.app) (GitHub Discussions-backed).
Configured in [`astro.config.ts`](astro.config.ts) from environment variables — see
[`.env.example`](.env.example) for the required keys. Locally, copy it to `.env` and
fill in the values from <https://giscus.app> for this repo. In CI, the same keys are
read from GitHub Actions secrets (`GISCUS_REPO`, `GISCUS_REPO_ID`, etc.) and injected
into the `build` job in [`ci.yml`](.github/workflows/ci.yml).

---

## Credits

Theme: [Spectre](https://github.com/louisescher/spectre) by louisescher (MIT-licensed).
Content & customisations: Muhammad Hamza.
