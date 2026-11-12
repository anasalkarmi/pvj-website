# PVJ website

Source for The Paediatric Video Journal website: a static site listing PVJ's conference
interviews by conference, topic and speaker. See `PLAN.md` for the plan and launch checklist.

## Folders

| Path | What it is |
|---|---|
| `content/` | The content. `videos.json` is the video library; `conferences.json`, `topics.json`, `site.json`, `pages.json` and `pages/*.html` hold the rest. **Edit here.** |
| `src/assets/` | Stylesheet, script, logo and icons. |
| `tools/` | PowerShell scripts: build, preview, YouTube import, checks. |
| `docs/` | The generated website (not kept in `main`; it is rebuilt every time and published to the `gh-pages` branch). **Never edit by hand.** |

## Everyday commands (Windows PowerShell, run from this folder)

Build the site:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\build.ps1
```

Preview it at http://localhost:4173/ (Ctrl+C to stop):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\serve.ps1
```

Check every video's thumbnails still exist on YouTube:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\check-thumbnails.ps1
```

## Changing content

- **Fix a title, role, topic or description:** edit the entry in `content/videos.json`, build, publish. Do not change a `slug` - it is the page's web address.
- **Edit a page such as About:** edit the file in `content/pages/`, build, publish.
- **Add videos after a new upload to YouTube:** see "Adding the next conference" in `PLAN.md` and the recipe in `AGENTS.md`.
- **Site-wide settings** (domain, contact email, social links, notice text): `content/site.json`.

## Transcripts and key points

- `content/transcripts/<youtubeId>.txt` holds a video's key points and transcript; the video page shows them when the file exists.
- `content/transcripts/UNCLEAR.tsv` lists every word shown on the site as `[unclear]`: transcripts are published without an audio check, and a word that could not be settled from PVJ's own text is marked instead of guessed. To fill one in, listen to the video, correct `content/transcripts/<youtubeId>.txt`, delete the line and publish. To keep a transcript off the site, list its id in `content/transcripts/_hold.tsv`.
- Transcripts start from YouTube's automatic captions, tidied for readability, so the site labels them as automatic transcripts.

## Publishing

Two branches on GitHub: `main` holds this source; `gh-pages` holds the built site, which GitHub Pages serves.

Publish the site (builds, then pushes the build to `gh-pages`):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\publish.ps1
```

Save source changes with ordinary git commits pushed to `main`.

`content/site.json` decides where the site lives:

| Setting | GitHub preview address | Real domain |
|---|---|---|
| `url` | `https://ACCOUNT.github.io` | `https://example.org` |
| `basePath` | `/REPO-NAME` | `""` |
| `domain` | `""` | `example.org` (writes the `CNAME` file) |
| `preview` | `true` (pages marked noindex, no sitemap) | `false` |

## Privacy notes

The site sets no cookies and has no analytics. Thumbnails load from YouTube's image servers; the
player loads from `youtube-nocookie.com` only after a visitor presses play. If analytics or a
newsletter form are added later, update `content/pages/privacy.html` at the same time.
