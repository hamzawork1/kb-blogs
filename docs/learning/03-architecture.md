# 03 — Architecture

This file zooms into the *site* itself. How are pages generated? Where does the data come from? How does the customised theme fit in?

By the end you'll be able to point at any file in `src/` and say what it does without guessing.

---

## The three architectural pillars

1. **The local `spectre` integration** — exposes site-wide config to all Astro components.
2. **Content collections** — every piece of content (post, project, sidebar entry) is a typed, schema-validated record loaded from disk.
3. **File-based routing with `getStaticPaths`** — every URL is enumerated at build time; no runtime routing.

Read those three things and you understand 95% of the site.

---

## Pillar 1 — The `spectre:globals` virtual module

### The problem it solves

Every Astro page / layout / component needs access to "site-wide config" — your name, the site title, the theme colour, the Open Graph defaults, Giscus comment settings. You could put this in a plain TypeScript file and `import` it everywhere, but the Spectre theme uses a slicker pattern that lets the config be validated, typed, and overridable from a single place: `astro.config.ts`.

### How it works

```
   astro.config.ts          spectre({ name, openGraph, giscus, ... })
        │
        v
   package/src/integration.ts
        │
        │   1. Zod schema validates the options.
        │   2. viteVirtualModulePluginBuilder creates a Vite plugin that
        │      registers a fake module called "spectre:globals".
        │   3. The plugin emits JS like:
        │         export const name = "Muhammad Hamza";
        │         export const openGraph = { ... };
        │         export const giscus = false;
        v
   Anywhere in src/:
        import { name, openGraph, giscus } from "spectre:globals";
```

There is no file named `spectre:globals` on disk. Vite intercepts the import, asks the plugin for the module's content, and inlines the resulting JS. Type information comes from `package/spectre-integration.d.ts`, which declares the shape of the virtual module to TypeScript.

### Where the seams are

Adding a new site-wide config value (say, a `mastodonHandle`) means touching **three files**:

1. **`package/src/integration.ts`** — extend the Zod `optionsSchema` to include the new field. Extend the virtual module template string at the bottom of the file to emit `export const mastodonHandle = ...`.
2. **`package/spectre-integration.d.ts`** — declare the new export's TypeScript type.
3. **`astro.config.ts`** — actually pass the new value when calling `spectre({ ... })`.

Then anywhere in `src/` you can `import { mastodonHandle } from "spectre:globals"`.

If you only edit two of the three, you'll either get a build-time validation failure (forgot the schema) or a TypeScript error (forgot the type declaration). The triple-touch is the cost of the pattern.

### Why this is worth it

The alternative is exporting a plain object from a TS file. That works, but:

- No validation — typos in `astro.config.ts` would silently propagate.
- No runtime guarantees that the value exists — the integration *throws at build time* if you pass a malformed Giscus config, for example.
- No clean separation between "theme contract" and "site customisation".

The virtual-module pattern is widely used in Astro themes for exactly these reasons.

---

## Pillar 2 — Content collections

### The mental model

Anything in `src/content/` is content. Each subfolder or JSON file is a *collection*. `src/content.config.ts` describes the shape of every collection using Zod schemas.

```
src/content.config.ts
        │
        │  defineCollection({ loader, schema })
        v
src/content/
├── posts/              ← collection: posts (glob loader, MDX files)
│   └── azure-vm-public-ip-upgrade-basic-to-standard.mdx
├── projects/           ← collection: projects (glob loader, MDX files; currently empty)
├── other/              ← collection: other (glob loader; only about.mdx today)
│   └── about.mdx
├── assets/             ← cover banners (NOT a collection — just an image folder referenced by post frontmatter)
│   ├── azure-cover.png
│   ├── devops-cover.png
│   └── ...
├── info.json           ← collection: quickInfo (file loader)
├── socials.json        ← collection: socials (file loader)
├── work.json           ← collection: workExperience (file loader)
└── tags.json           ← collection: tags (file loader)
```

When `getCollection("posts")` is called in a `.astro` page, Astro:

1. Reads every matching file from disk.
2. Validates each one against the collection's schema.
3. Returns a typed array.

If a post has a tag that isn't in `tags.json`, the build fails *immediately* with a clear error. If a post is missing a required frontmatter field, same. There is no way to publish broken content to production — the build won't even produce a `dist/`.

### The schemas, briefly

| Collection | Loader | Schema highlights |
|---|---|---|
| `posts` | `glob` over `src/content/posts/**/*.{md,mdx}` | `title`, `description`, `image` (must be a valid image path resolvable by Astro), `createdAt`, `updatedAt?`, `draft? = false`, `tags` (each `reference("tags")`) |
| `projects` | `glob` over `src/content/projects/**/*.{md,mdx}` | `title`, `description`, `date`, `image`, `link?`, `info` (array of `{ text, icon, link? }`) |
| `tags` | `file` over `src/content/tags.json` | `id` (must be a unique string) |
| `quickInfo` | `file` over `src/content/info.json` | `id`, `icon`, `text` |
| `socials` | `file` over `src/content/socials.json` | `id`, `icon`, `text`, `link` (must be a URL) |
| `workExperience` | `file` over `src/content/work.json` | `id`, `duration`, `company`, `title`, `description` |
| `other` | `glob` over `src/content/other/**/*.{md,mdx}` | unschematic; just MDX |

### The icon schema (a worked example)

`quickInfo`, `socials`, and `projects[].info` all reference icons. The schema is a discriminated union:

```typescript
const lucideIconSchema = z.object({
    type: z.literal("lucide"),
    name: z.custom<keyof typeof lucideIcons>(),
});

const simpleIconSchema = z.object({
    type: z.literal("simple-icons"),
    name: z.custom<keyof typeof simpleIcons>(),
});

icon: z.union([lucideIconSchema, simpleIconSchema])
```

The `keyof typeof lucideIcons` is the *actual* set of valid icon names imported from `@iconify-json/lucide/icons.json`. TypeScript will flag an unknown icon name at type-check time — not at runtime.

The renderer is `src/components/Icon.astro`, which fetches the SVG from `@iconify/utils` and inlines it.

### Why this matters

It means **the build fails if any content is malformed.** You can't accidentally ship a post with a tag that doesn't exist, an icon that's misspelled, a missing image, a typo in a date field, or a malformed URL in a social link. Every one of those is caught during `pnpm build` (and therefore in CI on every PR).

---

## Pillar 3 — Routing and rendering

### Static-only output

`astro.config.ts` sets `output: "static"`. No Astro adapter. Every URL the site serves is pre-built into a `dist/<path>/index.html` at build time.

That means:

- Every page in `src/pages/` becomes a static file.
- Dynamic routes (`[post].astro`, `[project].astro`) **must** declare `getStaticPaths` to enumerate every concrete URL.
- There is no `request` object at runtime. There's no per-request anything.

### Page-to-URL mapping

| File | URL |
|---|---|
| `src/pages/index.astro` | `/` |
| `src/pages/blog.astro` | `/blog` |
| `src/pages/blog/[post].astro` | `/blog/<post-slug>` for every non-draft post |
| `src/pages/projects.astro` | `/projects` |
| `src/pages/projects/[project].astro` | `/projects/<project-slug>` |
| `src/pages/404.astro` | `/404` (served on any unknown path; Cloudflare honors `not_found_handling = "404-page"` in `wrangler.toml`) |
| `src/pages/pagefind/pagefind.js.ts` | `/pagefind/pagefind.js` — a stub that returns empty results in dev (the real file is overwritten by the Pagefind CLI's output after build) |
| `src/pages/styles/giscus.ts` | `/styles/giscus` — a `prerender: true` endpoint that emits the Giscus CSS as a static asset |

### Anatomy of `src/pages/blog/[post].astro`

```astro
---
import type { CollectionEntry, GetStaticPaths } from "astro:content";
import { getCollection, render } from "astro:content";
// ... imports omitted ...

interface Props {
    post: CollectionEntry<"posts">;
}

const { post } = Astro.props;

export const getStaticPaths = (async () => {
    const posts = await getCollection("posts", (post) => post.data.draft !== true);
    return posts.map((post) => ({ params: { post: post.id }, props: { post } }));
}) satisfies GetStaticPaths;

const { Content, headings } = await render(post);
---

<Layout title={post.data.title} description={post.data.description} image={post.data.image}>
  <!-- TOC card, banner, title overlay, <Content /> -->
</Layout>
```

Three things to notice:

1. **`getStaticPaths` filters drafts.** Posts with `draft: true` simply don't get a route generated. They're invisible from the live site, not 404 — they don't exist as URLs.
2. **`Astro.props.post` is fully typed.** TypeScript knows the shape from the schema. Autocomplete works on `post.data.title`, `post.data.tags[0].id`, etc.
3. **`render(post)` returns `Content` (a component) + `headings` (array of `{ depth, slug, text }`).** The `headings` array drives the table-of-contents card on the left.

### The home page's data fan-out

`src/pages/index.astro` does six `getCollection` / `getEntry` calls in parallel:

```typescript
const [posts, projects, about, workExperience, quickInfo, socials] =
    await Promise.all([
        getCollection("posts", (post) => post.data.draft !== true),
        getCollection("projects"),
        getEntry("other", "about"),
        getCollection("workExperience"),
        getCollection("quickInfo"),
        getCollection("socials"),
    ]);
```

Each result is then rendered into the relevant card on the home page. Adding a new card (e.g. "Speaking engagements") means:

1. Add a new JSON file in `src/content/<name>.json`.
2. Add a `defineCollection` entry in `src/content.config.ts`.
3. Add a `getCollection("<name>")` call here.
4. Render the array into HTML in this file.

---

## The build pipeline (local, not CI)

When you run `pnpm build`:

```
1. astro build
     │
     ├── Validates every content collection against its schema.
     ├── For every page in src/pages/, generates HTML in dist/.
     ├── For every image referenced by frontmatter, runs Sharp to optimise
     │   and outputs to dist/_astro/.
     ├── Bundles CSS, JS, fonts, and other static assets.
     └── Writes dist/sitemap-index.xml + dist/sitemap-0.xml via @astrojs/sitemap.

2. postbuild: pagefind --site dist
     │
     ├── Crawls every HTML file in dist/ for elements with data-pagefind-body.
     ├── Builds a search index in dist/pagefind/.
     └── Writes the pagefind JS loader to dist/pagefind/pagefind.js.
```

After both steps, `dist/` is a self-contained website ready to be served by any static host. The CI pipeline uploads exactly this folder to the Cloudflare Worker.

### Why Pagefind specifically

Static-site search is hard because there's no server to query. The two viable approaches are (a) Algolia / similar SaaS, or (b) an index baked into the site itself. Pagefind takes approach (b). The index is split into chunks (per-letter, roughly), so the browser only fetches what it needs as the user types — total transferred is usually <100 KB for a small site. No external service to manage, no quotas, no rate limits.

The `data-pagefind-body` attribute on `<article>` in `[post].astro` tells Pagefind "index this region". `data-pagefind-ignore` on the navbar / sidebar tells it "skip this". You don't have to think about it day-to-day.

---

## Styling architecture

CSS in this project is plain CSS — no Tailwind, no CSS-in-JS. Files:

| File | Scope |
|---|---|
| `src/styles/reset.css` | Mild reset for browser inconsistencies |
| `src/styles/globals.css` | CSS custom properties (`--primary`, fonts, etc.), `body` defaults |
| `src/styles/background.css` | The animated background blobs |
| `src/styles/index.css` | Home page–specific |
| `src/styles/article.css` | Blog post page–specific (the banner overlay, TOC, headings) |
| `src/styles/article-list.css` | Blog list page–specific |
| `src/styles/giscus.css` | Theme for Giscus when enabled |

Theme colour tweaks happen in `src/styles/globals.css`:

```css
:root {
    --primary: #8c5cf5;
    --primary-rgb: 140, 92, 245;
    --primary-light: #a277ff;
    --primary-lightest: #c2a8fd;
}
```

Code-block syntax highlighting is **Expressive Code + Shiki**. The theme is defined in `src/ec-theme.ts` (a variation of GitHub's dark theme with custom background colours). Switching to a stock theme is a one-line change in `astro.config.ts` — see the Spectre theme's original docs or [`07-theme-structure.md`](./07-theme-structure.md).

---

## The article header overlay (a small but interesting detail)

Look at `src/styles/article.css` lines around `.article-header`, `.header`, `.article-h1`, `.article-info`.

The cover banner image is rendered full-width. The article title + date/tags are absolute-positioned at `bottom: 1.5rem; left: 1rem` — they overlay the banner's bottom-left corner.

Originally the title sat inside a white pill (`background: #ffffff`) so it was readable on any banner. That clashed with our tag-based banners (which already have a clean left side by design). We removed the pill background and switched the title to white text with `text-shadow: 0 2px 6px rgba(0, 0, 0, 0.7)` for legibility against any banner.

This is a good example of a **theme tweak that lives entirely in CSS** — no JavaScript, no integration changes, no schema impact.

---

## What you do *not* need to think about

In this architecture:

- **There's no server.** Nothing has to be running for the site to be available. Cloudflare's edge handles every request.
- **There's no database.** Content is files in Git.
- **There's no cache layer.** Cloudflare's CDN caches the static assets globally and invalidates on every deploy.
- **There's no auth.** No user accounts, no sessions, no JWT, no OAuth.
- **There's no runtime environment.** No `process.env` matters at run time (it matters at build time, e.g. for Giscus).

Most "what could go wrong" categories from server-side web apps simply don't apply.

---

Next: [04 — Setup journey](./04-setup-journey.md)
