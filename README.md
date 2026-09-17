# Job Search Documents

LaTeX ATS résumé, abstract, cover letter, and comprehensive master career history.

## Layout

- `src/*.tex`: top-level LaTeX documents.
- `src/content/`: hand-written sections still used by the abstract and other documents.
- `src/styles/` and `src/fonts/`: LaTeX class and fonts still used by the abstract and cover letter.
- `src/data/roles/`: one YAML record per professional role, imported from the master career history.
- `src/data/achievements/`: reusable achievement statements, with stable IDs.
- `src/data/contact.yaml`: shared name and contact details for the ATS résumé and master career history.
- `src/data/sections/`: one YAML file per other master-history section; records and bullet items have stable IDs. Education and selected certification records are also shared with the ATS résumé.
- `src/profiles/`: ordered selections of sections, records, roles, and bullet items.
- `src/profiles/resume-ats.yaml`: the ATS résumé's summary, compact skills, and role selections. Role technology lists come directly from `src/data/roles/`.
- `build/generated/`: generated LaTeX; do not edit it directly.
- `build/pdf/`: final and preview PDFs.
- `private/`: local evidence and notes; excluded from Git.
- `proofs/`: retained page images used for visual review.

Every section of the master career history is now rendered from YAML. The original files in `src/content/master_career_history/` remain as import snapshots, not active sources. The ATS résumé pulls its professional achievements from those same YAML records and follows the master-history bullet order. YAML-driven master-history profiles are available alongside it.

## Build

Requires XeLaTeX, `make`, and Ruby (with its built-in YAML library). The ATS PDF reading-order check also requires macOS Swift and PDFKit.

```sh
make                         # ATS résumé, abstract, and cover letter
make resume-ats
make master-career-history   # all master-history sections come from YAML
make profile PROFILE=selected-career-history
```

All PDFs are in `build/pdf/`. Profile builds do not replace `resume_ats.pdf` or `master_career_history.pdf`. `make clean` removes auxiliary files; `make distclean` also removes PDFs.

## Tailor a document

1. Find the role in `src/data/roles/<role-id>.yaml`. Its `achievement_ids` list is the complete inventory for that role.
2. Read the matching statements in `src/data/achievements/<role-id>.yaml`. The `text_tex` field permits LaTeX markup such as `\%` and `\&` and is inserted as LaTeX, so edit it carefully.
3. Copy a master-history profile in `src/profiles/`, give it a new lowercase, hyphenated filename, and choose role order and achievement IDs. A role can use `achievements: all` or omit that field to include every achievement. Add `achievement_order` to a role when you want to rearrange its selected bullets without changing the source inventory; it must list every selected ID exactly once.
4. Run `make profile PROFILE=<filename-without-.yaml>` and inspect the PDF.

For a tailored long-form history, use `document: master` and list sections in the order you want. A section entry can be its ID (all records) or an object with `id` and `blocks`. A block can similarly be its ID (all bullet items) or an object with `id` and `items`. To reorder bullets within a section record, give the section an `item_order` mapping from block IDs to complete, ordered lists of selected item IDs. See `src/profiles/master-career-history.yaml` for ordering and `src/profiles/selected-career-history.yaml` for selection examples. The master table of contents follows the selected sections automatically.

In section YAML, edit `name_tex`, `dates_tex`, `description_tex`, `title_tex`, `text_tex`, or a raw block's `tex`. Fields such as `prefix_tex`, `leading_tex`, and `item_open_tex` preserve LaTeX layout and normally should not need editing. All `*_tex` values are inserted as LaTeX, not automatically escaped. Profile rendering validates selected IDs before creating the document.

The initial YAML inventory was mechanically imported with `scripts/import_master_experience.rb` and `scripts/import_master_sections.rb`. Do not rerun those one-time imports after editing YAML: YAML is now the master-history source of truth.

Structured role data lives under `src/data/roles/`. The abstract still uses hand-written sections in `src/content/experience/`.

## ATS résumé default

Edit `src/profiles/resume-ats.yaml` to change the summary, skills, or selected achievement, education, and certification IDs. `achievement_order_from` automatically presents the selected achievement IDs in the order of the master career history, so the ATS résumé does not need a second hand-maintained bullet order. Both documents read contact details from `src/data/contact.yaml`, role titles and technologies from `src/data/roles/`, education from `src/data/sections/education.yaml`, and certification wording from `src/data/sections/credentials_and_continuing_education.yaml`. IBM technologies are stored at the company level in the master history; `company_technologies_from: ibm` displays that list once alongside the first IBM role in the ATS résumé. `src/resume_ats.tex` supplies the plain, single-column layout. `make resume-ats` regenerates the experience, education, and certifications and checks the PDF's extracted page count, section order, employer/title/date sequence, technology text, bullet count, and HSEA omission. The checker uses a generated Swift module cache under `build/generated/`.
