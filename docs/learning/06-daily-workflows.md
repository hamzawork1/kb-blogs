# 06 — Daily workflows

This is the file you'll re-open most. It documents the recurring "I want to do X" tasks: publish a post, add a project, edit an existing piece of content, manage tags and images, deploy to production.

Every workflow is structured the same way: **goal → steps → worked example → things that go wrong**.

---

## Publish a new blog post

### Goal

You wrote something. Get it onto `staging.mhamza.space` first, verify it, then promote to `mhamza.space`.

### Decision checklist (before opening any file)

- **Slug** — the URL-safe name of the post. Lowercase, hyphenated. Example: `azure-vnet-peering-step-by-step`. The URL will be `mhamza.space/blog/<slug>`.
- **Tag(s)** — which tags this post falls under. Must already exist in `src/content/tags.json`. Currently allowed: `guide`, `azure`, `devops`, `kubernetes`, `terraform`, `ci-cd`, `notes`. Multiple are fine.
- **Cover image** — pick the matching tag's banner. Example: a post tagged `azure` uses `../assets/azure-cover.png`. (See "Add a new tag" below if your topic doesn't fit any existing tag.)
- **Date** — `createdAt` in `YYYY-MM-DD`. Use the date you did the work, not the date you're publishing — it's more honest for technical content where API surfaces change.

### Steps

1. **Pull staging.**
   ```powershell
   git checkout staging
   git pull --ff-only origin staging
   ```

2. **Create the topic branch.**
   ```powershell
   git checkout -b post/azure-vnet-peering-step-by-step
   ```

3. **Create the post file** at `src/content/posts/azure-vnet-peering-step-by-step.mdx` with this skeleton:

   ```mdx
   ---
   title: "Azure VNet Peering — step-by-step"
   description: "How to wire two Azure VNets together via peering, with the gotchas around overlapping address spaces and the firewall rules you'll hit."
   image: "../assets/azure-cover.png"
   createdAt: 2026-06-01
   draft: false
   tags:
     - azure
     - guide
   ---

   ## Why peering?

   Body content here. Standard Markdown plus MDX.

   ```bash
   az network vnet peering create \
     --name peering-hub-to-spoke \
     --resource-group rg-network \
     --vnet-name vnet-hub \
     --remote-vnet vnet-spoke \
     --allow-vnet-access
   ```

   > Quoted callouts render with the primary accent.
   ```

4. **Preview locally.**
   ```powershell
   pnpm dev
   ```

   Open `http://localhost:4321/blog/azure-vnet-peering-step-by-step`. Verify:

   - Title and metadata pill render correctly over the cover banner.
   - Headings show up in the TOC sidebar.
   - Code blocks have syntax highlighting.
   - Internal/external links work.
   - Images you embedded (if any) load.

   Note: search is stubbed in `pnpm dev`. To test search, use `pnpm build && pnpm preview` instead.

5. **Commit.** Use a conventional message:

   ```powershell
   git add src/content/posts/azure-vnet-peering-step-by-step.mdx
   git commit -m "post: azure vnet peering step-by-step

   - Walks through the two CLI commands to peer hub and spoke VNets.
   - Covers the firewall NSG implications and the overlapping CIDR
     pitfall."
   ```

6. **Push and open PR to staging.**
   ```powershell
   git push -u origin post/azure-vnet-peering-step-by-step
   gh pr create --base staging --head post/azure-vnet-peering-step-by-step --title "post: azure vnet peering step-by-step" --body "..."
   ```

   PR description should include:
   - One-line summary
   - What you covered
   - Any "I'm not 100% sure about" callouts for self-review

7. **Wait for CI.** The `build` job runs (~30 seconds). If it fails, fix and push again. Common failures:
   - Tag in `tags:` doesn't exist in `tags.json` → add it (see "Add a new tag")
   - Image path is wrong → fix the relative path
   - Frontmatter date format wrong → use `YYYY-MM-DD`

8. **Merge to staging.** Use GitHub's UI: "Merge pull request" → "Confirm merge". This creates a merge commit on `staging`.

9. **Verify on staging.preview.** Within a minute, `https://staging.mhamza.space/blog/<slug>` should be live. Open it. Read your post one more time on the real site. Catch typos, broken images, bad line breaks. The staging environment is *for this*.

10. **Clean up the local topic branch.**
    ```powershell
    git checkout staging
    git pull --ff-only origin staging
    git branch -d post/azure-vnet-peering-step-by-step
    git push origin --delete post/azure-vnet-peering-step-by-step
    ```

11. **Ship to production** (when you've accumulated a batch — or immediately, if it's a single high-priority post).

    ```powershell
    gh pr create --base main --head staging --title "release: 2026-06-01 — Azure VNet peering post" --body "$(git log main..staging --pretty=format:'- %s')"
    ```

    Merge that PR. The push to `main` triggers a deploy to the production Worker. `mhamza.space/blog/<slug>` is live within a minute.

### Worked example: the post that exists in the repo today

`src/content/posts/azure-vm-public-ip-upgrade-basic-to-standard.mdx` — read it as a reference. It uses:

- Slug derived from filename: `azure-vm-public-ip-upgrade-basic-to-standard`
- Tags: `azure`, `devops`, `guide`
- Cover image: `../assets/azure-cover.png` (reusing the azure tag's banner)
- Date: `createdAt: 2025-07-22` (when the work was done, not when it was published)
- Real code blocks with PowerShell syntax highlighting
- A reference list at the bottom linking to Microsoft Docs

When you write your next post, copy that file's frontmatter as a starting point and replace.

### Common failure modes

| Symptom | Likely cause | Fix |
|---|---|---|
| `Failed to resolve image '../assets/xyz-cover.png'` | Cover image doesn't exist | Use one of the seven existing tag covers, or generate a new one (see "Add a new tag") |
| `Image is required` | Forgot `image:` frontmatter | Add it |
| `Could not find tag "<id>"` | Tag isn't in `tags.json` | Add it to `tags.json` first |
| Date renders weirdly on the page | YAML parsed your date as a string when it expected a date | Use unquoted `YYYY-MM-DD` (e.g. `createdAt: 2026-06-01`, no quotes) |
| Post appears in `pnpm dev` but not on staging after merge | `draft: true` in frontmatter (or its absence was overridden) | Set `draft: false` or remove the field entirely (default is false) |

---

## Edit an existing post

### Goal

Fix a typo. Add an update. Rewrite a section.

### When to bump `updatedAt`

If the change is meaningful (not just a typo), add `updatedAt: <today>` to the frontmatter. The layout displays this and the Open Graph meta tags pick it up — Google + social-card scrapers learn that the content was refreshed.

If the change is trivial (typo), skip `updatedAt` to avoid signalling false updates.

### Steps

```powershell
git checkout staging
git pull --ff-only origin staging
git checkout -b fix/azure-vnet-peering-cidr-typo
# edit src/content/posts/azure-vnet-peering-step-by-step.mdx
git add src/content/posts/azure-vnet-peering-step-by-step.mdx
git commit -m "fix(post): correct CIDR mask in VNet peering example"
git push -u origin fix/azure-vnet-peering-cidr-typo
gh pr create --base staging --head fix/azure-vnet-peering-cidr-typo --title "fix(post): correct CIDR mask in VNet peering example"
```

Same merge / verify / cleanup as a new post.

---

## Unpublish a post

### Goal

Make a post invisible without deleting it. Maybe the content is wrong; maybe you want to revise heavily before re-publishing.

### Steps

1. Branch:
   ```powershell
   git checkout -b chore/unpublish-azure-vnet
   ```

2. Edit the post's frontmatter — set `draft: true`:
   ```mdx
   ---
   title: "..."
   draft: true
   ---
   ```

3. Commit + PR + merge as usual.

After deploy, the post's URL returns the 404 page. The file is still in `src/content/posts/` so you can flip the flag back to `draft: false` later and republish.

**Why not just delete the file?** Two reasons:
- Git history preserves the deletion-vs-edit distinction. `draft: true` makes the intent explicit.
- Re-publishing later only needs `draft: false`, not "find the deleted file in the reflog and restore it".

---

## Add a new project

### Goal

Show a project on the `/projects` page.

### Decision checklist

- **Slug** — for the URL.
- **Date** — `date` field. The date the project shipped / was published.
- **Cover image** — same tag-based banner system as posts. Reuse `azure-cover.png` if it's an Azure project, etc.
- **Info entries** — the metadata pills shown on the project card. Common ones: GitHub link, live URL, npm package, blog post.

### Steps

Create `src/content/projects/<slug>.mdx`:

```mdx
---
title: My Project
date: 2026-05-25
description: One-line description shown on the projects list page.
image: ../assets/azure-cover.png
link: https://my-project.example.com
info:
  - text: GitHub
    link: https://github.com/hamzawork1/my-project
    icon:
      type: lucide
      name: github
  - text: Live demo
    link: https://my-project.example.com
    icon:
      type: lucide
      name: globe
---

Long-form description here. MDX is allowed; embed screenshots from
`src/content/assets/<slug>-screenshot-1.png` etc.
```

Branch / commit / PR / merge the same way as a post.

### Worked example

Look at the git history for `src/content/projects/portfolio-site.mdx` — it existed briefly as the "this site itself" example before being deleted in the cleanup. The structure is the model to follow.

---

## Add a new tag

### Goal

You want to tag a post `terraform-cloud` but that tag doesn't exist yet.

### Steps

1. **Add to `src/content/tags.json`.** Open the file, add the new tag's entry:
   ```json
   [
     { "id": "guide" },
     { "id": "azure" },
     { "id": "devops" },
     { "id": "kubernetes" },
     { "id": "terraform" },
     { "id": "ci-cd" },
     { "id": "notes" },
     { "id": "terraform-cloud" }
   ]
   ```

2. **Add a colour palette in `scripts/generate-covers.ps1`.** Open the file, find the `$Palettes` hash table, add an entry:
   ```powershell
   "terraform-cloud" = @{ Dark1 = @(50,15,70); Dark2 = @(150,80,200); Accent = @(220,180,255) }
   ```

   Pick colours that fit the topic. Three colours: `Dark1` is the upper-left gradient stop, `Dark2` is the lower-right gradient stop, `Accent` is the cube highlight.

3. **Generate the banner.**
   ```powershell
   pwsh scripts/generate-covers.ps1 -Tag terraform-cloud
   ```

   This writes `src/content/assets/terraform-cloud-cover.png`.

4. **Commit all three changes together** on a topic branch:
   ```powershell
   git checkout -b feature/add-terraform-cloud-tag
   git add src/content/tags.json scripts/generate-covers.ps1 src/content/assets/terraform-cloud-cover.png
   git commit -m "feature: add terraform-cloud tag and cover banner

   - tags.json: new entry { id: terraform-cloud }.
   - generate-covers.ps1: palette entry (deep purple gradient, light
     purple accent — distinct from generic terraform).
   - assets/terraform-cloud-cover.png: generated banner."
   git push -u origin feature/add-terraform-cloud-tag
   gh pr create --base staging --head feature/add-terraform-cloud-tag --title "feature: add terraform-cloud tag and cover banner"
   ```

5. Merge after CI green.

Now `tags: [terraform-cloud]` is valid in any post's frontmatter, and that post can use `image: "../assets/terraform-cloud-cover.png"`.

### Regenerating all banners at once

If you change the visual design in the script (different cube layout, different overlay), regenerate every banner in one shot:

```powershell
pwsh scripts/generate-covers.ps1
```

(no `-Tag` argument = generate all). Commit the updated PNGs.

---

## Update the home page

The home page is `src/pages/index.astro`. It pulls from six content collections to populate the cards.

| Card | Data source |
|---|---|
| Profile + quick info pills | `src/content/info.json` (loaded as `quickInfo` collection) |
| Socials list | `src/content/socials.json` |
| About text block | `src/content/other/about.mdx` |
| Work experience timeline | `src/content/work.json` (loaded as `workExperience`) |
| Latest posts preview | `src/content/posts/` (filtered, `draft: false` only) |
| Featured projects preview | `src/content/projects/` |

To change any of those, edit the source file. All follow the same branch / PR / merge flow.

### Quick info pills

Edit `src/content/info.json`. Each pill has an icon (Lucide or Simple Icons) and a text. Order matters — first entry shows first.

```json
[
  {
    "id": 1,
    "icon": { "type": "lucide", "name": "briefcase" },
    "text": "Azure Cloud & DevOps Engineer"
  },
  {
    "id": 2,
    "icon": { "type": "lucide", "name": "globe" },
    "text": "Remote / Worldwide"
  },
  {
    "id": 3,
    "icon": { "type": "simple-icons", "name": "microsoftazure" },
    "text": "Azure · DevOps · IaC"
  }
]
```

To find icon names: browse <https://lucide.dev> or <https://simpleicons.org>. The schema validates names against the actual icon set JSON, so a typo fails the build.

### Socials

Edit `src/content/socials.json`. Same structure as quick info, plus a `link`:

```json
{
  "id": 1,
  "icon": { "type": "lucide", "name": "github" },
  "text": "GitHub",
  "link": "https://github.com/hamzawork1"
}
```

For email, use a `mailto:` URL: `"link": "mailto:devops.engineer099@gmail.com"`.

### About

Edit `src/content/other/about.mdx`. Plain MDX. The content renders inside the about card on the home page. Keep it short — three to four sentences is the right length.

### Work experience

Edit `src/content/work.json`. Each entry:

```json
{
  "id": 1,
  "duration": "2024 — Present",
  "company": "Acme Corp",
  "title": "Senior DevOps Engineer",
  "description": "One- or two-sentence summary."
}
```

Order matters — first entry shows first. Convention: most recent first.

If you want to keep your work history *not* public (you said you might prefer this), one option: replace company names with `"company": "Anonymised — multi-cloud SaaS"` or similar. Still gives credibility without revealing employers.

---

## Promote `staging` to `main` (production deploy)

### Goal

Take everything currently on `staging` and ship it to production.

### When to do this

A deliberate decision, never on auto-pilot. Common triggers:

- New posts have been live on staging for at least a couple of hours and visually verified
- A feature change has been tested
- A batch of small fixes has accumulated

Avoid:

- Auto-merging staging → main on every push to staging (defeats the purpose of having two environments)
- Promoting half-finished work because "it's been on staging for a while"

### Steps

1. **Make sure staging is in the state you want production to be in.** Visit `https://staging.mhamza.space`. Click around. Read a couple of posts. Check OG previews on social media debuggers (Facebook Sharing Debugger, Twitter Card Validator).

2. **Open the PR.**
   ```powershell
   gh pr create --base main --head staging --title "release: 2026-06-01 — <one-line summary>" --body "$(git log main..staging --pretty=format:'- %s')"
   ```

   The body uses `git log main..staging` to list every commit that's in staging but not yet in main. That becomes the release notes.

3. **Merge via GitHub UI.** Use "Create a merge commit" — this preserves the per-PR commit history that landed on staging. (Solo project, so any merge style works; merge commits are easiest to read in `git log`.)

4. **Watch the deploy.** The push to `main` triggers a CI run. Production Worker `mhamza-space` is updated. `mhamza.space` serves the new content within a minute.

5. **Update `CHANGELOG.md`** in a small follow-up commit on its own branch. Cut everything from `[Unreleased]` into a new dated section:

   ```markdown
   ## [2026-06-01]

   ... contents of [Unreleased] go here ...

   ## [Unreleased]
   ```

   Push that as a `docs/changelog-cut-2026-06-01` branch → PR → merge to staging.

### What if something is wrong in production?

See [08 — Troubleshooting](./08-troubleshooting.md) → "Production deploy went bad".

In one sentence: Cloudflare dashboard → Worker `mhamza-space` → Deployments → click "Rollback" on the previous version. Live in seconds.

---

## Replace the profile photo

`src/assets/pfp.png` — the photo on the home page.

Requirements:
- PNG format (the path is `.png`; if you have a JPG, convert)
- Square aspect ratio
- At least 240×240 px (the layout displays at 120×120, but a 240 source allows for Retina / high-DPI displays)
- ~50–500 KB is a healthy size range

Steps:

1. Branch:
   ```powershell
   git checkout -b chore/update-profile-photo
   ```

2. Replace the file on disk (drag-and-drop in your file manager, or `cp` in a shell).

3. Verify dimensions (run from the repo root):
   ```powershell
   Add-Type -AssemblyName System.Drawing
   $path = (Resolve-Path .\src\assets\pfp.png).Path
   $img = [System.Drawing.Image]::FromFile($path)
   "$($img.Width) x $($img.Height) px, $((Get-Item $path).Length) bytes"
   $img.Dispose()
   ```

4. Commit + PR + merge as usual.

If your source is a JPG, convert first (run from the repo root):

```powershell
Add-Type -AssemblyName System.Drawing
$src = [System.Drawing.Image]::FromFile("path\to\your\photo.jpg")
$dest = Join-Path (Get-Location) "src\assets\pfp.png"
$src.Save($dest, [System.Drawing.Imaging.ImageFormat]::Png)
$src.Dispose()
```

---

## Quick reference card

You'll memorise these eventually. Until then, this is the cheat sheet.

```powershell
# Start a new piece of work (any kind)
git checkout staging
git pull --ff-only origin staging
git checkout -b <type>/<short-name>     # post/, feature/, fix/, docs/, ci/, chore/

# ... do the work, commit incrementally ...

# Push and open PR
git push -u origin <type>/<short-name>
gh pr create --base staging --head <type>/<short-name>

# After merge — clean up
git checkout staging
git pull --ff-only origin staging
git branch -d <type>/<short-name>
git push origin --delete <type>/<short-name>

# Ship to production (a batch of staging work)
gh pr create --base main --head staging --title "release: <date> — <summary>"
```

That's the entire daily cycle. Everything else in this kit explains *why* these steps are shaped the way they are.

---

Next: [07 — Theme structure](./07-theme-structure.md)
