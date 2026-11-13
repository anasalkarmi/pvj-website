# Instructions for AI agents (Codex, Claude) working on the PVJ website

Read `README.md` and `PLAN.md` first. This file holds the rules and the recipes.

## Rules

- `content/` is the source of truth. `docs/` is generated and git-ignored: never edit it by hand, always rebuild. `tools/publish.ps1` builds and pushes the result to the `gh-pages` branch; source changes are ordinary commits on `main`.
- Never change an existing `slug` in `content/videos.json`. It is the public URL of that video.
- Facts come from PVJ's own material (YouTube titles and descriptions, the owner's instructions). Do not add, "correct" or embellish names, roles, affiliations or claims from outside knowledge. If something looks wrong, list it for the owner instead.
- Do not invent organisational facts (team, board, sponsors, peer review, accreditation). The owner's own mission text on the About page calls PVJ "independent"; use that word only where he has.
- The owner's brief for the home page (12 November 2026): PVJ is a video journal for all of paediatrics, not the site of one conference. Order: his statement of what PVJ is, then the clinical areas, then the conferences, then the latest videos. Do not lead with a conference or a single specialty.
- British English. Plain, professional wording.
- The site must stay free of cookies, trackers and third-party scripts unless the owner asks, and then `content/pages/privacy.html` must change in the same piece of work.
- Do not publish (commit, push, change DNS) without the owner's go-ahead.
- Thumbnails: show the owner the design and get a yes before uploading anything to YouTube. The approved layout is the one in `tools/make-thumbnails.ps1`; a new layout needs a new yes.
- Do not message speakers, partners or anyone else on PVJ's behalf without the owner approving the exact wording and the channel.

## Topics (`content/topics.json`)

- A topic without `"group"` is a clinical area: it gets a badge on the home page, with the icon `src/icons/clinical/<slug>.svg` (see `src/icons/README.md` for the source and licence). Keep clinical names short ("Neurology", not "Neurology and neurodisability"): the owner asked for that.
- `"group": "theme"` marks a cross-cutting subject (research, education, policy and so on). Themes appear on the Topics page only, never on the home page.
- A topic with no videos is not shown anywhere (Immunology was in that state when it was added).
- `"about"` is the paragraph under the one-line description on a topic's page (added for search engines, 12 November 2026). It names the subjects of the videos filed there, using only words from those videos' titles and summaries: no speakers, hospitals or conferences, no counts, no advice, no praise. Re-read it when videos are added to or moved out of a topic.
- A topic slug is a public address. To replace a topic, give the new one `"aliases": ["old-slug"]`: the build then writes a forwarding page at the old address.

## PowerShell gotchas in `tools/`

- Scripts must stay plain ASCII: Windows PowerShell 5.1 misreads non-ASCII script files. Put non-ASCII text in the JSON content files, which are read as UTF-8.
- Do not name a function after a built-in alias. `H` (Get-History) and `LP` (Out-Printer) both bit this project; aliases win over functions silently.
- Read and write files with `[IO.File]` and an explicit UTF-8 encoding without BOM, not `Get-Content` / `Set-Content` / `>`.
- `ConvertFrom-Json` on an array: assign with `-InputObject`, then enumerate. `@(... | ConvertFrom-Json)` nests the array in 5.1.
- Paths can exceed 260 characters; the build uses the `\\?\` prefix through its `LongPath` helper. Keep using it for anything written under `docs/`.

## Checks to run before saying a change is done

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\build.ps1
```

The build stops with "DATA PROBLEM" lines if `videos.json` has an unknown topic or conference, a
duplicate slug or a malformed YouTube id. Then preview with `tools\serve.ps1` and look at the pages
you changed at phone width (375 px) and desktop width.

## Recipe: add newly uploaded videos

1. `powershell -NoProfile -ExecutionPolicy Bypass -File tools\youtube-harvest.ps1 -OutFile work\import\youtube-harvest.json`
   reads the public channel (no login). `work/` is not committed.
2. `powershell -NoProfile -ExecutionPolicy Bypass -File tools\import-youtube.ps1 -Check` lists the new videos as "NOT ENRICHED YET".
3. For those videos write `work\import\enrich-<conference-slug>.json`: an array of
   `{ "id", "title", "speakers": [{ "name", "role" }], "topics": [1 to 3 slugs from content/topics.json], "summary" (one sentence, 160 characters at most), "notes" }`.
   - `title`: the YouTube title; if it has the form "Topic | Speaker", keep only the topic part.
   - `name` and `role`: exactly as the description states them (drop a leading "A"/"An" and praise words such as "leading").
   - Topics by subject, most specific first.
   - Owner's rule (12 November 2026): every video from a PCCS conference also sits under `critical-care`, whatever else it is about. The import does not add this: put `critical-care` last in the topics of each PCCS video in `content/videos.json` after importing. Videos from general conferences such as RCPCH are filed by subject only.
4. Add the conference to `content/conferences.json` if it is new (slug must match the enrich file name).
5. Run `tools\import-youtube.ps1` (adds only new videos; existing entries are left untouched), then build and preview.
6. Resolve every WARNING the import prints. Known typos in YouTube text go in `work\import\text-fixes.json`.

## Recipe: transcripts and key points for new videos

YouTube only serves captions to its own pages, so they are collected in a signed-in browser tab:
open any video on youtube.com, press "Show transcript", and read the `transcript-segment-view-model`
elements. For many videos, loop over them in the page (navigate with a `yt-navigate` event on
`ytd-app`), then send the result to `tools\caption-receiver.ps1` by pointing the tab at
`http://localhost:<port>/recv?part=1#<url-encoded JSON of { youtubeId: text }>`.

1. `tools\prepare-transcript-batches.ps1` splits the saved captions into work packs in `work\transcripts\`.
2. Tidy each pack following `work\transcripts\BRIEF.md` (fidelity rules, key points, file layout).
3. `tools\validate-transcripts.ps1` compares every transcript with its captions; fix until it passes.
4. This is a clinical audience: never publish a guessed drug, diagnosis, score, organisation, number or
   person's name. A word the tidier is unsure about (garbled, or only a best reading) is either settled
   from PVJ's own text (the YouTube title and description) or written as `[unclear]`, and it never
   appears in a key point. Everyday words whose meaning is obvious from the sentence may be repaired.
   Decision of 12 November 2026 (Anas): transcripts go on the site without waiting for someone to check
   them against the audio, so `[unclear]` is the safeguard. Every `[unclear]` has a line in
   `content\transcripts\UNCLEAR.tsv` (what the captions said), so that someone who listens to the video
   can fill the word in and delete the line.
5. `tools\validate-transcripts.ps1` accepts `[unclear]` and no other bracketed note. To keep one
   transcript off the site, list its YouTube id in `content\transcripts\_hold.tsv`.

## Recipe: thumbnails in the PVJ layout

1. `tools\thumbnail-candidates.ps1` fetches four stills per video into `work\thumbnails\frames\` and makes numbered sheets with pixel rulers.
2. Write one plan row per video (format at the top of `tools\make-thumbnails.ps1`; the 2024 and 2025 plan is `src\thumbnails\plan-rcpch-2024-2025.tsv`). Pick the still where the speaker looks best and no on-screen caption shows; `cropX` puts the face in the middle of the 674 px photo.
3. `tools\make-thumbnails.ps1 -Plan <file> -SheetName <name>` renders them and a contact sheet. Look at the whole sheet before uploading: cut-off headlines, a face behind the panel, a wrong name.
4. Copy the stills a plan uses into `src\thumbnails\stills\`: once a thumbnail is uploaded, YouTube no longer serves the video's old default frame.
5. Upload in YouTube Studio (video > Details > Thumbnail), one video at a time, then run `tools\check-uploaded-thumbnails.ps1`, which compares what YouTube serves with the rendered files.

## Recipe: a conference's picture and logo

- The picture on a conference's card and at the top of its page is the conference photo with three interview stills down the right-hand side (the layout the owner approved for PCCS 2026 and asked to repeat). `tools\make-conference-picture.ps1` makes it from the photo and three stills in `src\thumbnails\stills\` (use the `cropX` from the thumbnail plan); the header of that script explains the options. Pick stills of three different speakers from that conference, none of them the person in the main photo. Save it as `src\assets\img\conferences\<conference-slug>.jpg` and set `"image"` in `content\conferences.json`.
- `"logo"` in `content\conferences.json` is shown to the left of the card text: a round badge by default, or `"logoShape": "wide"` for a wordmark (RCPCH). Conference photos and logos belong to the organisers and come from the owner or with his say-so; a logo here does not make the organiser a partner (`partnerLogo` is only for partnerships the owner has confirmed).

## Recipe: a speaker asks for a correction (name, role, affiliation)

The speaker's own word, passed on by the owner or Anas, outranks the YouTube description. The same text usually sits in three places, so correct all three:

1. The site: the speaker's `role` and the `description` in `content\videos.json`, then build and publish. Add the phrase to `work\import\text-fixes.json` so a later import does not bring the old wording back, and add a line to the corrections list in `PLAN.md` section 3.
2. YouTube: the video's description in YouTube Studio, under PVJ's own Google account (Studio may open under another signed-in account and say there is no permission).
3. LinkedIn: the PVJ page's post for that interview (links are in `work\outreach\pccs-linkedin-comments.csv` for PCCS 2026). The posts end with "Related organisations:" and a tagged organisation, which is where a wrong affiliation shows most.

A name caption inside the video itself can only be changed by re-exporting the video; tell the owner if that applies.

## Checking the live site

`tools\check-live.ps1` asks GitHub's servers directly for the home page, both `www` and bare addresses over http and https, the sitemap, the feed and the 404 page, and says whether the site is hidden from search engines.

## Work that suits a cheaper model

- Step 3 above (structured extraction and topic tagging), with the import cross-checks as the safety net.
- Drafting or revising copy in `content/pages/` from facts the owner supplies.
- Image preparation with `tools\make-assets.ps1`.
- Thumbnail plan rows and the YouTube Studio uploads, with the contact sheet and `tools\check-uploaded-thumbnails.ps1` as the checks.

Design changes, the build script and anything that publishes should stay with the lead agent and the owner.
