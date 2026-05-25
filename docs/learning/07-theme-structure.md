# 07 — Theme structure

A map of "I want to change <something visible> — which file?". The site's visual layer is dark-themed and minimalist by default. Most changes are CSS-only and ship via a normal topic-branch PR.

This file complements [06 — Daily workflows](./06-daily-workflows.md) — that file taught you the *flow*, this one teaches you the *where*.

---

## Mental model

Three concentric layers of styling:

1. **Site-wide design tokens** — colours, typography, spacing. Defined as CSS custom properties in `src/styles/globals.css`. Change once, everything updates.
2. **Layout / shell** — header, footer, the two-column grid on most pages. Lives in `src/layouts/Layout.astro` + `src/components/LayoutGrid.astro`.
3. **Per-page styling** — page-specific CSS in `src/styles/*.css`, imported by the relevant page (`index.astro`, `blog.astro`, `[post].astro`, etc.).

Walk from layer 1 inward when changing visual design — start with tokens, then layout, then page-specific.

---

## Layer 1 — Design tokens

### Primary colour

`src/styles/globals.css`:

```css
:root {
    --primary: #8c5cf5;
    --primary-rgb: 140, 92, 245;
    --primary-light: #a277ff;
    --primary-lightest: #c2a8fd;
}
```

`--primary` is the accent colour used for:

- Links (`<a>` colour)
- Blockquote left-border + tinted background
- TOC active item background
- Theme colour meta tag (browser chrome on mobile)
- Default cover banner palette

`--primary-light` and `--primary-lightest` are link hover / focus variants.

`--primary-rgb` is the same value as `--primary` in `r, g, b` form — needed for `rgba(var(--primary-rgb), 0.25)` style alpha-mixing.

**Change them in sync.** If you change `--primary`, also change `--primary-rgb`, `--primary-light`, and `--primary-lightest` to a consistent palette. A tool like <https://colorbox.io> or <https://accessiblepalette.com> can generate the three variants from a base.

The `themeColor` config in `astro.config.ts` (passed to `spectre({ ... })`) controls the `<meta name="theme-color">` tag in the HTML head. Keep that in sync with `--primary` too. Default value (when not set) is `#8c5cf5`, matching the CSS.

### Fonts

The site uses **Geist** for body text and **Geist Mono** for code. The font files are at `public/fonts/Geist.woff2` and `public/fonts/GeistMono.woff2`. They're preloaded in `Layout.astro`'s `<head>`.

To swap fonts:

1. Drop new `.woff2` files into `public/fonts/`.
2. Update the `@font-face` declarations in `src/styles/globals.css`.
3. Update the preload links in `src/layouts/Layout.astro`.
4. Delete the old `.woff2` files.

Geist + Geist Mono are licensed under the SIL Open Font License and ship with the site.

### Background

`src/components/Background.astro` is the animated soft-coloured blobs in the page background. The colours and positions are in `src/styles/background.css`. To disable the background entirely, edit `src/layouts/Layout.astro` and remove the `<Background />` component (the page will fall back to solid `#000` from the body's CSS).

---

## Layer 2 — Layout / shell

### `src/layouts/Layout.astro`

The single layout for every page. Responsibilities:

- HTML `<head>` — meta tags, fonts, OG tags, theme-color, sitemap link
- `<body>` skeleton — background, navbar, the two-column grid, footer
- Reads `name`, `themeColor`, `twitterHandle` from `spectre:globals`

The layout takes these props:

```typescript
interface Props {
    title?: string;        // <title> and og:title
    description?: string;  // og:description, twitter:description
    image?: ImageMetadata; // og:image (the post's cover image flows in here)
    article?: {            // optional — adds article-specific OG tags
        createdAt: Date;
        updatedAt?: Date;
    };
    pagefindIgnore?: boolean;  // skip this page in search
}
```

If you want a page that doesn't fit the two-column grid (e.g. a wide hero section), you currently have two choices:

1. Build a new layout component (e.g. `WideLayout.astro`) that omits the grid. Some duplication with `Layout.astro` is OK.
2. Wrap a single `<div>` inside the existing layout and use CSS to break out of the grid.

For now option 1 is cleaner. Add the new layout when a real wide-layout page appears.

### `src/components/LayoutGrid.astro`

The two-column grid used on most pages. Left column is typically a card (profile, TOC), right column is content. On screens narrower than 640 px the columns stack vertically.

The pages that use it pass content via Astro's named slot system:

```astro
<Layout title="...">
  <Card slot="left">...</Card>
  <article slot="right">...</article>
</Layout>
```

### `src/components/Navbar.astro`

The top navbar. Contains the site name link (left) and the navigation links + search (right). Edit links here:

```astro
<a href="/">Home</a>
<a href="/blog">Blog</a>
<a href="/projects">Projects</a>
```

Adding a new top-level page: create `src/pages/<name>.astro`, then add a `<a href="/<name>">` to the navbar.

### `src/components/Card.astro`

The bordered card visual used everywhere — profile card, post preview, project card, TOC, comments wrapper. A passthrough `<section>` with a class. The styling is in `src/styles/index.css` (`.flex-col-card`, `.post-container`, etc.) and `src/styles/article.css` (`.toc-card`).

---

## Layer 3 — Per-page styling

| Page | Stylesheet | What's inside |
|---|---|---|
| `src/pages/index.astro` | `src/styles/index.css` | Profile card flex, post preview grid, work experience list, socials list |
| `src/pages/blog.astro` | `src/styles/article-list.css` | The blog list page — post cards, search box positioning |
| `src/pages/blog/[post].astro` | `src/styles/article.css` | Article page — TOC card sticky positioning, cover banner overlay, title pill, headings, blockquotes, tables, code-inline styling |
| `src/pages/projects.astro` | inherits article-list.css | Projects list — similar to blog list |
| `src/pages/projects/[project].astro` | inherits article.css | Individual project page |
| Global (every page) | `src/styles/globals.css`, `src/styles/reset.css`, `src/styles/background.css` | Tokens, reset, animated background |

To override a style on a single page:

1. Identify the right stylesheet by the page's `import "..."` at the top of the `.astro` file's frontmatter.
2. Edit that file. Class names follow BEM-ish conventions (`.toc-card`, `.toc-card ol`, `.toc-li[data-depth="3"]`, etc.).

---

## Code-block styling (Expressive Code + Shiki)

Code blocks in MDX (anything fenced with triple-backticks) are rendered by **Expressive Code**, which uses **Shiki** for syntax highlighting.

The theme is defined in `src/ec-theme.ts` — a variation of GitHub's dark theme with custom background colours that fit the site's dark aesthetic.

### Switching to a stock theme

If you want a different code colour scheme, edit `astro.config.ts`:

```ts
import { defineConfig } from 'astro/config';
import expressiveCode from 'astro-expressive-code';

export default defineConfig({
  integrations: [
    expressiveCode({
      themes: ['catppuccin-mocha'],   // any from https://expressive-code.com/guides/themes/
    }),
    // ...
  ],
});
```

Replace `['catppuccin-mocha']` with whichever theme name you like. The Expressive Code site lists every supported theme.

### Customising the existing theme

Edit `src/ec-theme.ts` directly. It's a JavaScript object that follows the [Shiki theme schema](https://shiki.style/themes#loading-custom-themes). Common edits: change a specific token's colour (e.g. make string literals brighter), change the code-block background to match the site's background exactly.

### Code-block frame / title

Expressive Code shows a frame around code blocks with optional title and file-name pill. You can add a title in MDX:

````mdx
```bash title="bash"
echo "hello"
```
````

Or a filename:

````mdx
```typescript title="src/example.ts"
const x: number = 1;
```
````

The frame styling is part of Expressive Code's default CSS — you don't have to touch anything to get it.

---

## Cover banner system (recap)

This was covered in [02](./02-tooling-primer.md) and [06](./06-daily-workflows.md), but it's worth seeing the file structure all in one place:

```
src/content/assets/
├── azure-cover.png
├── ci-cd-cover.png
├── devops-cover.png
├── guide-cover.png
├── kubernetes-cover.png
├── notes-cover.png
└── terraform-cover.png

scripts/
└── generate-covers.ps1
```

- Posts reference banners via relative path: `image: "../assets/<tag>-cover.png"`.
- Banner generator: `pwsh scripts/generate-covers.ps1` (all) or `pwsh scripts/generate-covers.ps1 -Tag azure` (one).
- Palettes are in the script's `$Palettes` hash table — three colours per tag (`Dark1`, `Dark2`, `Accent`).

### Customising banner design

If you want a completely different banner look (different layout, different shapes, different overlay):

1. Edit the geometry / drawing calls in the `New-CoverImage` function in `scripts/generate-covers.ps1`.
2. Run `pwsh scripts/generate-covers.ps1` (no `-Tag`) to regenerate every banner with the new design.
3. Commit the updated `.ps1` + every regenerated PNG.

The script uses .NET's `System.Drawing` API. Useful primitives:

- `$g.FillRectangle(brush, rect)` — solid or gradient rectangle
- `$g.FillEllipse(brush, x, y, w, h)` — circle/ellipse
- `$g.FillPolygon(brush, points[])` — arbitrary polygon (used for the isometric cubes)
- `$g.DrawLine(pen, x1, y1, x2, y2)` — stroke
- `$g.DrawString(text, font, brush, x, y)` — text rendering

If you want a non-PowerShell version (e.g. Node + Sharp + a SVG-to-PNG library), the architecture is open to it — just keep the contract: input is a tag name, output is `src/content/assets/<tag>-cover.png` at 1200×630.

---

## Article header anatomy (the overlay trick)

When you visit a post, the title and date/tags appear absolute-positioned over the bottom-left of the cover banner. This is the most visually distinctive piece of the theme. Let's pull it apart.

### The HTML

In `src/pages/blog/[post].astro`:

```astro
<div class="article-header" id="_top" data-pagefind-ignore>
  <ImageGlow class="article-image" src={post.data.image} alt={post.data.title} />
  <div class="header">
    <div>
      <h1 class="no-mt article-h1">{post.data.title}</h1>
    </div>
    <div class="article-info">
      <span>{post.data.createdAt.toLocaleDateString()}</span>
      <span>/</span>
      <span>{timeToRead(post)} minute(s) to read</span>
      <span>/</span>
      <span>Tags: {post.data.tags.map((tag) => tag.id).join(", ")}</span>
    </div>
  </div>
</div>
```

### The CSS (`src/styles/article.css`)

```css
.article-header {
    position: relative;
    width: 100%;
    height: fit-content;
}

.article-image {
    width: 100%;
    height: auto;
    z-index: 1;
}

.header {
    position: absolute;
    bottom: 1.5rem;
    left: 1rem;
    max-width: calc(100% - 3rem);
    z-index: 2;
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
}

.article-h1 {
    font-size: 2em;
    color: #ffffff;
    text-shadow: 0 2px 6px rgba(0, 0, 0, 0.7);
    display: inline;
    box-decoration-break: clone;
}

.article-info {
    font-family: "Geist Mono", monospace;
    color: #ffffff;
    text-shadow: 0 2px 6px rgba(0, 0, 0, 0.7);
}

@media screen and (max-width: 640px) {
    .header {
        position: relative;
        margin-top: 1rem;
    }
}
```

### Key things

- The `.article-header` is `position: relative` so its children can be absolutely positioned within it.
- The `.article-image` flows as a normal block at `z-index: 1`.
- The `.header` block (containing title + info) is absolutely positioned at the bottom-left at `z-index: 2`, layering on top of the image.
- The `text-shadow: 0 2px 6px rgba(0, 0, 0, 0.7)` is what makes the white text readable on the (always-dark) banner. If you switched to light-themed banners, you'd need to switch the text colour to black with a light text-shadow.
- On screens narrower than 640 px, the absolute positioning is dropped — the title/info block flows below the image instead. Otherwise mobile would have title overlapping a too-narrow image.

### Why the banner has a clean left side

Because the title overlay lives at bottom-left, the banner generator puts all its visual interest on the right side. Otherwise the title would overlap the cubes and look messy. This is the *contract* between the generator and the CSS: generator promises clean left, CSS promises title sits there.

If you change the layout (e.g. centre the title), update the generator to put visual interest somewhere else.

---

## Comments (Giscus) — when you want to enable

Giscus posts each blog post as a discussion thread in your GitHub repo. Visitors authenticate via GitHub and can comment.

Steps to enable:

1. Go to <https://giscus.app> and follow the configurator. You'll need:
   - Your repo (`hamzawork1/kb-blogs`) configured as **public** *or* with Discussions enabled
   - The **category** to map posts to (typically a "General" or "Comments" Discussions category)

2. Giscus gives you values for `repository`, `repositoryId`, `category`, `categoryId`, etc.

3. Add them to a local `.env` file (template in `.env.example`):
   ```
   GISCUS_REPO=hamzawork1/kb-blogs
   GISCUS_REPO_ID=R_xxxxx
   GISCUS_CATEGORY=Comments
   GISCUS_CATEGORY_ID=DIC_xxxxx
   GISCUS_MAPPING=pathname
   GISCUS_STRICT=true
   GISCUS_REACTIONS_ENABLED=true
   GISCUS_EMIT_METADATA=false
   GISCUS_LANG=en
   ```

4. In `astro.config.ts`, uncomment the `loadEnv` block at the top and the `giscus: { ... }` block inside the `spectre({ ... })` call. Replace `giscus: false` with the object.

5. Local preview to verify: `pnpm dev`. Comments will appear at the bottom of each post page.

6. For CI/CD: same env-vars need to be set as repo secrets. Add `GISCUS_REPO`, `GISCUS_REPO_ID`, etc. as new secrets in repo Settings → Secrets and variables → Actions. Then update `.github/workflows/ci-cd.yml` to pass them into the build step:

   ```yaml
   - name: Build (Astro + Pagefind index)
     run: pnpm build
     env:
       GISCUS_REPO: ${{ secrets.GISCUS_REPO }}
       GISCUS_REPO_ID: ${{ secrets.GISCUS_REPO_ID }}
       # ... etc
   ```

7. Commit + PR + merge through staging → main as usual.

If/when you do this, add an ADR (`docs/decisions/0004-comments-giscus.md`) explaining the tradeoff: pro = real comments with low ops; con = users must have a GitHub account to comment.

---

## Where everything is — quick lookup

| Want to change | File |
|---|---|
| Site name in browser tab / OG | `astro.config.ts` → `spectre({ name: "..." })` |
| OG defaults per top-level page | `astro.config.ts` → `openGraph: { home, blog, projects }` |
| Primary accent colour | `src/styles/globals.css` → `--primary` family |
| Code-block colour scheme | `src/ec-theme.ts` (or replace with stock theme in `astro.config.ts`) |
| Fonts | `public/fonts/*.woff2` + `src/styles/globals.css` `@font-face` |
| Background blobs | `src/components/Background.astro`, `src/styles/background.css` |
| Navbar links | `src/components/Navbar.astro` |
| Home page sections | `src/pages/index.astro` |
| Blog list layout | `src/pages/blog.astro`, `src/styles/article-list.css` |
| Post page layout (TOC, header, body) | `src/pages/blog/[post].astro`, `src/styles/article.css` |
| Footer | `src/layouts/Layout.astro` (bottom of `<body>`) |
| Profile picture | `src/assets/pfp.png` (overwrite, keep filename) |
| 404 page | `src/pages/404.astro` |
| Sidebar quick info | `src/content/info.json` |
| Sidebar socials | `src/content/socials.json` |
| Work experience | `src/content/work.json` |
| About block | `src/content/other/about.mdx` |
| Tags (allowed list) | `src/content/tags.json` |
| Cover banners | `src/content/assets/*-cover.png` (regenerate via `scripts/generate-covers.ps1`) |

Bookmark this table. Most changes start here.

---

Next: [08 — Troubleshooting](./08-troubleshooting.md)
