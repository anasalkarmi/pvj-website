# PVJ website plan

The Paediatric Video Journal (PVJ) website, modelled on video journals such as VJOncology:
a video journal for all of paediatrics, browsable by clinical area and topic, by conference and by speaker.

Status on 12 November 2026: **the site is live at https://paediatricvj.com and open to search engines** (`"preview": false` in `content/site.json`; it has a sitemap and an RSS feed). The About, Editorial policy, Work with PVJ, Privacy and Terms pages are still first drafts that the owner has not signed off (see section 6). To hide the site from search engines again, set `"preview": true` and run `tools\publish.ps1`.

## 1. What the reference site does, and what PVJ takes from it

| VJOncology | PVJ version 1 |
|---|---|
| "For healthcare professionals" notice bar | Same, one line at the top of every page |
| Mega-menu: Diseases, Topics, Conferences | Videos, Topics, Conferences, Speakers, About |
| Home: intro, congress tiles, trending videos, channels | Home: the owner's statement of what PVJ is, clinical areas, conferences, latest videos, partner call-to-action (order set by the owner, see 6b) |
| Conference pages with all coverage | One page per conference with every interview |
| Expert index | A to Z speaker index, one page per speaker |
| Video page: player, speaker, date, related | Same, plus topics, share buttons and a link to the LinkedIn post |
| Features, VJSessions, Podcasts, Trials, Medicines | Not in version 1 (no such content yet) - see roadmap |
| Sign-up / newsletter | Not in version 1 - see roadmap |
| Supporters, Editorial Board | Left out until PVJ has them; Editorial policy page is drafted |

## 2. Site map (269 pages)

- `/` home
- `/videos/` all 123 videos with search and conference/topic filters
- `/videos/<slug>/` one page per video (123)
- `/conferences/` and `/conferences/<slug>/` (PCCS 2026, RCPCH 2025, RCPCH 2024)
- `/topics/` and `/topics/<slug>/` (24 topics)
- `/speakers/` and `/speakers/<slug>/` (107 speakers)
- `/about/`, `/about/editorial-policy/`, `/work-with-us/`, `/contact/`
- `/privacy/`, `/terms/`, `404.html`
- `sitemap.xml`, `feed.xml` (RSS), `robots.txt`

## 3. Content

All 123 public videos on the PVJ YouTube channel were imported on 11 November 2026:

| Conference | Videos |
|---|---|
| PCCS Conference 2026, Lord's, London | 48 |
| RCPCH Conference 2025, Glasgow | 51 |
| RCPCH Conference 2024, Birmingham | 24 |

Titles, descriptions, dates and durations come straight from YouTube. Speaker names and roles
were extracted from the descriptions and machine-checked against them. Each video has 1 to 3
topics and a one-sentence summary used on cards and in search results.

Corrections made on the site (the YouTube descriptions still contain these typos):

- "Benerjee" corrected to "Banerjee" (RCPCH 2024, "Ethnic Diversity of Children and Young People with ADHD")
- "Cardiff and Yale University Health Board" corrected to "Vale" (RCPCH 2024, "Why People Choose Not to Be Vaccinated?")
- "Orthopaediac" corrected to "Orthopaedic" (RCPCH 2024, bone and soft tissue tumour referrals)
- "Warickshire" corrected to "Warwickshire" (RCPCH 2024, unaccompanied asylum seeking children)
- Six speaker roles had "A leading ..." / "A distinguished ..." trimmed to a plain job description

## 4. Design

- Colours from the PVJ logo: red `#9E2A2B`, teal `#155A75`, on the warm paper background used on the PVJ thumbnails.
- System fonts only (nothing downloaded from font services).
- Works from 375 px phones to wide desktop; checked at 375 and 1280.
- Video thumbnails are the ones already on YouTube.

## 5. How it is built and hosted

- A static site: plain HTML, one CSS file, one small JavaScript file. No database, no CMS, no monthly cost.
- `content/*.json` is the content. `tools/build.ps1` turns it into the `docs/` folder; `tools/publish.ps1` pushes that build to the `gh-pages` branch, which GitHub Pages serves.
- The build needs only Windows PowerShell, which every Windows PC has. No Node, Python or installs.
- Privacy by default: the site sets no cookies and has no analytics. The YouTube player loads only when a visitor presses play, from YouTube's privacy-enhanced domain, so no cookie banner is needed.
- Custom domain: `paediatricvj.com`, registered at GoDaddy. Its DNS points at GitHub Pages (four A records for the bare domain to 185.199.108-111.153, one CNAME for `www` to the GitHub account's `github.io` name), with free HTTPS from GitHub.
- The same GoDaddy account also holds `paediatricvj.co.uk`, `pediatricvj.com` and `pediatricvj.co.uk`. Each one is forwarded (permanent, 301) to `https://paediatricvj.com` with GoDaddy's domain forwarding, so every spelling lands on the site.

## 6. Launch state and approvals still owed

Done: domain connected (bare and `www`, both with a valid HTTPS certificate), repository and hosting set up, contact email on the Contact page, site opened to search engines on 12 November 2026. `tools\check-live.ps1` re-checks all of this in a few seconds.

The site was opened before the owner had signed off the following, so they are still owed:

1. **Draft pages** - About, Editorial policy, Work with PVJ, Privacy and Terms are drafts written from known facts. The owner should read and approve them. Terms assume the law of England and Wales.
2. **"Intended for healthcare professionals"** - confirm this wording for the notice bar and footer.
3. **PCCS logo** - shown on the PCCS 2026 page as "In partnership with". Confirm PCCS is happy with that use.
4. **Legal identity** - Privacy and Terms name "The Paediatric Video Journal" only. Add the company or owner name if there is one.
5. **Google Search Console** - registered on 12 November 2026 under PVJ's own Google account (the `paediatricvj@gmail.com` one), as the URL-prefix property `https://paediatricvj.com/`, verified by the file the build writes from `"googleSiteVerification"` in `content/site.json` (do not remove it). `sitemap.xml` was submitted and read the same day: 270 pages, 123 videos.

## 6a. Added on 12 November 2026

- Key points, an automatic transcript and a "cite this video" line on video pages: all 123 videos have them. The last 55 transcripts were released on 12 November 2026 without an audio check; words that could not be settled are shown as `[unclear]` and listed in `content/transcripts/UNCLEAR.tsv`.
- Speaker pictures taken from each speaker's most recent solo interview.
- The 75 RCPCH video titles shown in sentence case, matching the 2026 titles (the YouTube titles are unchanged).
- Work with PVJ page: the PCCS 2026 facts and an enquiry panel.
- The YouTube channel links to the site, and every one of the 123 video descriptions ends with a line pointing to it (`tools\import-youtube.ps1` drops that line again so it does not appear on the site).
- All 75 RCPCH 2024 and 2025 videos have thumbnails in the PVJ layout with a red accent (the owner's contact chose "option B"), uploaded to YouTube and checked there one by one. Speaker pictures on the site are cut from the same thumbnails, so the crop was changed to match.

How the 2024 and 2025 thumbnails are made (to repeat it or change one):

1. `tools\thumbnail-candidates.ps1` downloads four stills per video from YouTube and lays them out as numbered sheets.
2. The plan file `src\thumbnails\plan-rcpch-2024-2025.tsv` names, per video, the still, where the face sits, the speaker's name and a three-line headline.
3. `tools\make-thumbnails.ps1 -Plan src\thumbnails\plan-rcpch-2024-2025.tsv` renders 1280x720 files into `work\thumbnails\final\`.
4. Upload in YouTube Studio (video > Details > Thumbnail > Upload file > Save). `tools\check-uploaded-thumbnails.ps1` then confirms what is live.

The stills are YouTube's own automatic frames (the best of four per video), not hand-picked from the footage. To use a better still, save it at 1280x720 as `src\thumbnails\stills\<youtubeId>-4.jpg`, put `4` in the frame column of that video's plan row and re-render. The 75 stills the plan uses are kept in `src\thumbnails\stills\`, because uploading a thumbnail replaces the video's old default frame on YouTube; the rendered files are in `work/`, which is not in the repository, and can be rendered again at any time.

Still to do, and who it needs:

- Telling the speakers their page exists: on 12 November 2026 a comment linking to the video's page was posted from the PVJ LinkedIn page under each of the 48 PCCS 2026 posts (wording says "with key points and a transcript" only where a transcript is published). Not done: personal messages, and anything for the RCPCH 2024 and 2025 speakers, who have no PVJ LinkedIn post. `work\outreach\` holds the list of 107 speakers with their page links and a draft message; it needs the owner's wording, channel and contacts.
- A listener: the words marked `[unclear]` in the transcripts (`content/transcripts/UNCLEAR.tsv`).
- The owner's approval of the draft pages (section 6).
- The owner's accounts or decisions: a newsletter provider, visitor statistics, an ISSN application, an editorial board.

## 6b. The owner's feedback, 12 November 2026 (WhatsApp text and voice notes)

What he asked for, and what was done:

- "It's a video journal platform", not a conference site. His one-sentence statement is now the first thing on the home page and is the site's description everywhere (`tagline` in `content/site.json`).
- Home page order: the statement, then the clinical areas (so a neurologist, or a funder, sees "there is a neurology page" at once), then the conferences, then the latest videos. Topics are split into clinical areas and cross-cutting themes with `"group": "theme"` in `content/topics.json`.
- Every PCCS video sits under Paediatric critical care as well as its own subjects; RCPCH videos are spread across the clinical areas by subject.
- His three-paragraph mission text opens the About page, word for word.
- A "Contact us" button stays in the bottom-right corner of every page and opens the Contact page.

Second round the same day ("much better"), and what was done:

- The PVJ logo sits beside the title in the top block; the counts of videos and speakers were removed ("maybe once we've got 3,000 videos").
- The home page lists clinical areas only, as small badges with an icon each, so that all of them are visible on the first screen. The other topics (research, AI, policy and so on) are on the Topics page.
- Shorter names: Adolescent health, Emergency care, Gastroenterology, Neurology, Respiratory, Surgery.
- "Oncology and haematology" became Oncology and Haematology; "Infection, immunity and allergy" became Infection, Allergy and Immunology. The 14 videos were re-filed by subject; vaccination videos went under Infection, which leaves Immunology with no videos, so it is not shown yet. The two old addresses forward to Infection and Oncology.
- The PCCS 2026 card on the home page uses the conference banner he sent, and each conference card has a "Watch the videos from this conference" link. He said he will send pictures and logos for the two RCPCH conferences.
- YouTube and LinkedIn buttons were added at the bottom of the home page.

With the banner he wrote "maybe add something PCC related here as like a side image, to match design of the conference". The site now shows his banner with three stills from PCCS 2026 interviews down the right-hand side (`src/assets/img/conferences/pccs-2026.jpg`, used on the home page card and at the top of the PCCS 2026 page). Whether that is what he meant is for him to say.

Asked for but waiting on material or a later stage:

- A picture of each conference itself on the conference cards, instead of a video thumbnail: done for PCCS 2026 with his banner; the two RCPCH cards keep a video thumbnail until he sends their pictures (`"image"` in `content/conferences.json`).
- An editorial board and the people who decide what is published: he called this "a later stage".
- He plans to email the site for feedback once the home page is right, and to use it in grant and funding applications.

## 6c. Search engines (the owner asked for this by phone, 12 November 2026)

An audit of every built page found the technical base sound (unique titles and descriptions, canonical addresses, one main heading per page, a complete sitemap, valid video data, no trackers). Changes made the same day:

- Topic, speaker and conference pages now show each video's one-line summary, so those pages have real text for a search engine to read.
- Structured data: breadcrumbs on every page that shows them, a Person record on each speaker page, the PVJ logo on the organisation record and on each video's publisher. "The Pediatric Video Journal" is recorded as an alternative name (the owner holds the pediatricvj domains).
- The sitemap now describes each of the 123 videos (thumbnail, title, summary, player, length, date).
- Page titles: long video titles no longer run past what Google shows; short ones ("Allergy", a speaker's name) now end with "The Paediatric Video Journal".
- The home page has a shorter description for search results; the statement on the page itself is unchanged.

What decides ranking from here, and is not in the code:

1. **Google Search Console**: done on 12 November 2026 (PVJ's Google account; sitemap read, 270 pages and 123 videos found; the home page was already in Google's index). Look at the Pages and Video pages reports there after a week or two to see what has been indexed.
2. **Links in**: the 123 YouTube descriptions link to the home page; a link to each video's own page would be better. PCCS, RCPCH and speakers' institutions linking to their pages matters more than anything on the site.
3. **More text**: two or three sentences of description per clinical area (`content/topics.json`). (All 123 transcripts are on the site since 12 November 2026.)
4. Nobody can promise first place for general searches. A search for the journal's own name should find it within weeks of indexing; subject searches depend on items 2 and 3 and on time.

## 7. Roadmap after launch

Phase 2 (content quality)
- Fix the four typos above in the YouTube descriptions.
- Add the site to the LinkedIn page.
- Short speaker biographies (optional `content/speakers.json`).
- RCPCH logo on the RCPCH conference pages, if permitted.
- Read the Pages and Video pages reports in Google Search Console once Google has crawled the sitemap.
- Listen for the words marked `[unclear]` in the transcripts and fill them in (`content/transcripts/UNCLEAR.tsv`).

Phase 3 (growth, as PVJ produces the content)
- Newsletter sign-up.
- Features: highlight films, round-table sessions, podcasts.
- Privacy-friendly visitor statistics.
- A "Partners and supporters" page and an editorial board, when they exist.

## 8. Adding the next conference

1. Publish the videos on YouTube as usual.
2. Run `tools\youtube-harvest.ps1` to read the channel, then enrich the new videos (speakers, topics, summary) - see `AGENTS.md`.
3. Add the conference to `content/conferences.json`.
4. Run `tools\import-youtube.ps1`, then `tools\build.ps1`, check the preview, and publish.
