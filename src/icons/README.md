# Clinical area icons

- Set: Health Icons
- Repository: https://github.com/resolvetosavelives/healthicons (site: https://healthicons.org)
- Style: outline (48 x 48 viewBox), `public/icons/svg/outline/...`
- Licence, quoted from the repository README.md: "These icons are available in the public domain (CC0) for use in any type of project." (The README also says: "The icons and the npm packages are in the public domain (CC0). The code for this website is under the MIT License".)
- Date collected: 12 November 2026

Cleaning applied: removed `width`/`height`; every colour is `currentColor` (or `fill="none"` on the root); only svg and path elements remain. Path data is unchanged. `fill-rule`/`clip-rule` attributes kept as in the originals.

| Our file | Original icon (outline style) |
|---|---|
| adolescent-transition.svg | people/young-people.svg |
| allergy.svg | conditions/allergies.svg |
| critical-care.svg | specialties/critical-care.svg |
| dermatology.svg | specialties/dermatology.svg |
| emergency-medicine.svg | vehicles/ambulance.svg |
| gastro-nutrition.svg | body/stomach.svg |
| genetics-rare-disease.svg | body/dna.svg |
| haematology.svg | body/blood-drop.svg |
| immunology.svg | body/antibody.svg |
| infection.svg | body/bacteria.svg |
| medicines.svg | medications/medicines.svg |
| mental-health.svg | specialties/psychology.svg |
| neonatology.svg | people/baby-0203m.svg |
| neurology.svg | body/neurology.svg |
| oncology.svg | conditions/ribbon.svg |
| respiratory.svg | body/lungs.svg |
| surgery-trauma.svg | specialties/general-surgery.svg |

`general.svg` (a page of text) is not from Health Icons: it was drawn for this site on 14 November 2026 as the picture for a research roundup paper that fits no clinical area. It is not a topic and has no badge on the home page.

The research roundup (`tools/make-roundup.ps1`) uses these same files as the picture beside each ranked paper.
