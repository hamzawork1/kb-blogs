# Runbook — Add a new blog post

End-to-end workflow for publishing a new post, following the project's
[branch strategy](../../README.md#branch-strategy).

> **TL;DR:** topic branch off `staging` → write post → push → PR to `staging`
> → verify preview → merge → PR `staging` → `main` to publish.

## Decide upfront

- **Slug** (URL-safe, lowercase, hyphenated). E.g. `azure-vnet-peering-guide`.
  The URL becomes `mhamza.space/blog/<slug>`.
- **Cover image** — pick the tag that fits your post (azure, devops,
  kubernetes, terraform, ci-cd, notes, guide). The cover banner for that tag
  is already in `src/content/assets/<tag>-cover.png` — reuse it. **Don't
  generate a new cover per post.** See [README — Image strategy](../../README.md#image-strategy).
- **Tags** — must already exist in `src/content/tags.json`. To add a new tag,
  see *"Adding a new tag"* below.

## Steps

### 1. Branch

```powershell
git checkout staging
git pull origin staging
git checkout -b post/<slug>
```

### 2. Create the post file

```
src/content/posts/<slug>.mdx
```

Frontmatter template:

```mdx
---
title: "Post title goes here"
description: "1-2 line summary. Shown in the blog list and OG previews."
image: "../assets/<tag>-cover.png"
createdAt: YYYY-MM-DD
draft: false
tags:
  - <tag>
---

## Section heading

Body here. Standard Markdown plus MDX.

```bash
# fenced code blocks get syntax highlighting via Expressive Code
az account show
```

> Quote blocks render with the primary accent colour.
```

### 3. (If the post has in-body images)

1. Drop image files in `src/content/assets/`. Name them `<slug>-<n>.png`.
2. Reference inline:
   ```mdx
   ![alt text](../assets/<slug>-1.png)
   ```
3. Keep each image under 500 KB (PNG for screenshots, JPG/WebP for photos).

### 4. Preview locally

```powershell
pnpm dev              # fast iteration; search is stubbed in dev
# or, for a production-faithful preview (search works):
pnpm build && pnpm preview
```

Visit `http://localhost:4321/blog/<slug>` to verify rendering, code blocks,
images, and the OG title pill over the cover banner.

### 5. Commit

```powershell
git add src/content/posts/<slug>.mdx src/content/assets/<slug>-*
git commit -m "post: <short title in lowercase>

- 1-2 line summary of what the post covers.
- Mention any non-obvious choices (e.g. why a specific code sample was abbreviated)."
```

### 6. Push and open PR

```powershell
git push -u origin post/<slug>
gh pr create --base staging --head post/<slug> \
  --title "post: <short title>" \
  --body "Adds <slug>.mdx and any related assets. Closes #<issue> if applicable."
```

### 7. Verify on Cloudflare preview

When the PR is opened, Cloudflare Pages posts a preview URL as a check. Open
it and re-verify:

- [ ] Post renders correctly.
- [ ] Cover image overlays the title pill cleanly.
- [ ] Code blocks have syntax highlighting.
- [ ] Search (`/`) finds your post.
- [ ] Tag links work.

### 8. Merge to staging

If happy, merge the PR. CI / Pages will redeploy staging.

### 9. Ship to production

Once a few posts (or fixes) have collected on staging and you're ready to
push them to mhamza.space:

```powershell
gh pr create --base main --head staging \
  --title "release: <date> — <one-line summary>" \
  --body "$(git log main..staging --pretty=format:'- %s')"
```

Merge the staging→main PR to deploy production.

### 10. Update the changelog (optional but recommended)

After the staging→main merge, add an entry to `CHANGELOG.md` under
`[YYYY-MM-DD]` (production deploy date):

```md
### Added
- New post: **<Post Title>** — `<slug>`.
```

Commit this update on a tiny topic branch or directly on staging.

---

## Adding a new tag

If your post needs a tag that doesn't exist yet:

1. Edit `src/content/tags.json`, add an entry: `{ "id": "<tag-id>" }`.
2. Edit `scripts/generate-covers.ps1`, add a `$Palettes` entry:
   ```powershell
   "<tag-id>" = @{ Dark1 = @(R,G,B); Dark2 = @(R,G,B); Accent = @(R,G,B) }
   ```
3. Generate the cover banner:
   ```powershell
   pwsh scripts/generate-covers.ps1 -Tag <tag-id>
   ```
4. Commit `tags.json`, `scripts/generate-covers.ps1`, and the new
   `src/content/assets/<tag-id>-cover.png` together.

---

## Editing an existing post

Use a `fix/<slug>` topic branch off staging if the fix is small. For
substantial edits, bump `updatedAt` in the frontmatter:

```mdx
createdAt: 2025-07-22
updatedAt: 2026-06-15
```

Search engines pick up the `updatedAt` to know the content was refreshed.

---

## Unpublishing a post

Don't delete the file. Set `draft: true` in its frontmatter — the post page
will 404, but the URL stays reserved and the file stays in Git history. To
republish later, flip back to `draft: false`.
