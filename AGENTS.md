# Instructions for AI agents (Codex, Claude) working on the PVJ website

Read `README.md` and `PLAN.md` first. This file holds the rules and the recipes.

## Rules

- `content/` is the source of truth. `docs/` is generated and git-ignored: never edit it by hand, always rebuild. `tools/publish.ps1` builds and pushes the result to the `gh-pages` branch; source changes are ordinary commits on `main`.
- Never change an existing `slug` in `content/videos.json`. It is the public URL of that video.
- Facts come from PVJ's own material (YouTube titles and descriptions, the owner's instructions). Do not add, "correct" or embellish names, roles, affiliations or claims from outside knowledge. If something looks wrong, list it for the owner instead.
- Do not invent organisational facts (team, board, sponsors, peer review, accreditation, the word "independent").
- British English. Plain, professional wording.
- The site must stay free of cookies, trackers and third-party scripts unless the owner asks, and then `content/pages/privacy.html` must change in the same piece of work.
- Do not publish (commit, push, change DNS) without the owner's go-ahead.

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
   - Topics by subject, most specific first. Do not tag a video `critical-care` only because of where it was filmed.
4. Add the conference to `content/conferences.json` if it is new (slug must match the enrich file name).
5. Run `tools\import-youtube.ps1` (adds only new videos; existing entries are left untouched), then build and preview.
6. Resolve every WARNING the import prints. Known typos in YouTube text go in `work\import\text-fixes.json`.

## Work that suits a cheaper model

- Step 3 above (structured extraction and topic tagging), with the import cross-checks as the safety net.
- Drafting or revising copy in `content/pages/` from facts the owner supplies.
- Image preparation with `tools\make-assets.ps1`.

Design changes, the build script and anything that publishes should stay with the lead agent and the owner.
