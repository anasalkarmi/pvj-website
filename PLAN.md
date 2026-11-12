# PVJ website plan

The Paediatric Video Journal (PVJ) website, modelled on video journals such as VJOncology:
a browsable library of short conference interviews, organised by conference, topic and speaker.

Status on 12 November 2026: **the site is live at https://paediatricvj.com and open to search engines** (`"preview": false` in `content/site.json`; it has a sitemap and an RSS feed). The About, Editorial policy, Work with PVJ, Privacy and Terms pages are still first drafts that the owner has not signed off (see section 6). To hide the site from search engines again, set `"preview": true` and run `tools\publish.ps1`.

## 1. What the reference site does, and what PVJ takes from it

| VJOncology | PVJ version 1 |
|---|---|
| "For healthcare professionals" notice bar | Same, one line at the top of every page |
| Mega-menu: Diseases, Topics, Conferences | Videos, Conferences, Topics, Speakers, About |
| Home: intro, congress tiles, trending videos, channels | Home: intro + latest interview, featured conference, latest videos, topic tiles, conferences, partner call-to-action |
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
5. **Google Search Console** - not registered yet. It needs a Google account that should own the listing (PVJ's, not an editor's) and one DNS record at GoDaddy.

## 6a. Added on 12 November 2026

- Key points, an automatic transcript and a "cite this video" line on video pages: 68 videos have them; 55 more transcripts wait in `content/transcripts/_review/` for a check against the audio.
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
- A listener: the 55 transcripts in the review folder.
- The owner's approval of the draft pages (section 6).
- The owner's accounts or decisions: Google Search Console, a newsletter provider, visitor statistics, an ISSN application, an editorial board.

## 7. Roadmap after launch

Phase 2 (content quality)
- Fix the four typos above in the YouTube descriptions.
- Add the site to the LinkedIn page.
- Short speaker biographies (optional `content/speakers.json`).
- RCPCH logo on the RCPCH conference pages, if permitted.
- Register the site with Google Search Console and submit `sitemap.xml`.
- Check the 55 held transcripts against the audio and publish them.

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
