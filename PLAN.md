# PVJ website plan

The Paediatric Video Journal (PVJ) website, modelled on video journals such as VJOncology:
a browsable library of short conference interviews, organised by conference, topic and speaker.

Status on 12 November 2026: **version 1 is live at https://paediatricvj.com in soft-launch mode** - anyone with the address can use it, but every page asks search engines not to list it until the owner approves the draft pages (see section 6). To open it to search engines, set `"preview": false` in `content/site.json` and run `tools\publish.ps1`.

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
- `sitemap.xml`, `feed.xml` (RSS), `robots.txt` once the domain is set

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

## 6. Before the full launch - approvals needed

Done: domain connected, repository and hosting set up, contact email on the Contact page.

Still needed before search engines are let in:

1. **Draft pages** - About, Editorial policy, Work with PVJ, Privacy and Terms are drafts written from known facts. The owner should read and approve them. Terms assume the law of England and Wales.
2. **"Intended for healthcare professionals"** - confirm this wording for the notice bar and footer.
3. **PCCS logo** - shown on the PCCS 2026 page as "In partnership with". Confirm PCCS is happy with that use.
4. **Legal identity** - Privacy and Terms name "The Paediatric Video Journal" only. Add the company or owner name if there is one.
5. **Then switch on indexing** - `"preview": false` in `content/site.json`, publish, and register the site with Google Search Console.

## 6a. Added on 12 November 2026

- Key points, an automatic transcript and a "cite this video" line on video pages: 68 videos have them; 55 more transcripts wait in `content/transcripts/_review/` for a check against the audio.
- Speaker pictures taken from each speaker's most recent solo interview.
- The 75 RCPCH video titles shown in sentence case, matching the 2026 titles (the YouTube titles are unchanged).
- Work with PVJ page: the PCCS 2026 facts and an enquiry panel.
- The YouTube channel links to the site.
- Thumbnail design samples for the 75 older videos are in `work/thumbnails/samples/` awaiting the owner's choice; nothing was uploaded.

Still to do, and who it needs:

- Owner's click: the bulk edit that adds the site link to all 123 YouTube descriptions.
- Owner's choice: thumbnail option A or B, then make and upload the 75 thumbnails. Videos whose YouTube frame shows the on-screen name caption need a clean still from the original footage.
- A listener: the 55 transcripts in the review folder.
- Owner's approval of the draft pages, then open the site to search engines and register it with Google Search Console.
- Owner's accounts or decisions: a newsletter provider, visitor statistics, an ISSN application, an editorial board.

## 7. Roadmap after launch

Phase 2 (content quality)
- Custom thumbnails for the 2024 and 2025 videos so they match the 2026 style.
- Fix the four typos above in the YouTube descriptions.
- Add the site link to YouTube descriptions and the channel page; add the site to the LinkedIn page.
- Speaker photos and short biographies (optional `content/speakers.json`).
- RCPCH logo on the RCPCH conference pages, if permitted.
- Register the site with Google Search Console and submit `sitemap.xml`.

Phase 3 (growth, as PVJ produces the content)
- Transcripts on video pages (good for search and accessibility).
- Newsletter sign-up.
- Features: highlight films, round-table sessions, podcasts.
- Privacy-friendly visitor statistics.
- A "Partners and supporters" page and an editorial board, when they exist.

## 8. Adding the next conference

1. Publish the videos on YouTube as usual.
2. Run `tools\youtube-harvest.ps1` to read the channel, then enrich the new videos (speakers, topics, summary) - see `AGENTS.md`.
3. Add the conference to `content/conferences.json`.
4. Run `tools\import-youtube.ps1`, then `tools\build.ps1`, check the preview, and publish.
