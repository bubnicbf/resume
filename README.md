# Job Search Documents

LaTeX ATS résumé and comprehensive master career history.

## Layout

- `src/resume_ats.tex` and `src/master_career_history.tex`: the two document layouts.
- `src/content/master_career_history/`: original import snapshots, not active sources.
- `src/data/roles/`: one YAML record per professional role, imported from the master career history.
- `src/data/achievements/`: reusable achievement statements, with stable IDs.
- `src/data/contact.yaml`: shared name and contact details for the ATS résumé and master career history.
- `src/data/sections/`: one YAML file per other master-history section; records and bullet items have stable IDs. Education and selected certification records are also shared with the ATS résumé.
- `src/profiles/`: ordered selections of sections, records, roles, and bullet items.
- `src/profiles/resume-ats.yaml`: the ATS résumé's summary, compact skills, and role selections. Role technology lists come directly from `src/data/roles/`.
- `build/generated/`: generated LaTeX; do not edit it directly.
- `build/pdf/`: final PDFs.
- `private/`: local evidence and notes; excluded from Git.
- `proofs/`: retained page images used for visual review.

Every section of the master career history is rendered from YAML. The ATS résumé pulls its professional achievements from those same YAML records and follows the master-history bullet order.

## Build

Requires XeLaTeX, `make`, and Ruby (with its built-in YAML library). The ATS PDF reading-order check also requires macOS Swift and PDFKit.

```sh
make                         # ATS résumé and master career history
make resume-ats
make master-career-history   # all master-history sections come from YAML
```

The two PDFs are in `build/pdf/`. `make clean` removes auxiliary files; `make distclean` also removes PDFs.

## Tailor a document

1. Find the role in `src/data/roles/<role-id>.yaml`. Its `achievement_ids` list is the complete inventory for that role.
2. Read the matching statements in `src/data/achievements/<role-id>.yaml`. The `text_tex` field permits LaTeX markup such as `\%` and `\&` and is inserted as LaTeX, so edit it carefully.
3. Edit `src/profiles/resume-ats.yaml` to change the résumé's selections, or `src/profiles/master-career-history.yaml` to change the master history's ordering.
4. Run `make resume-ats` or `make master-career-history` and inspect the PDF.

The master profile lists sections in display order. A section entry can be its ID (all records) or an object with `id` and `blocks`. A block can similarly be its ID (all bullet items) or an object with `id` and `items`. To reorder bullets within a section record, give the section an `item_order` mapping from block IDs to complete, ordered lists of selected item IDs. The master table of contents follows the selected sections automatically.

In section YAML, edit `name_tex`, `dates_tex`, `description_tex`, `title_tex`, `text_tex`, or a raw block's `tex`. Fields such as `prefix_tex`, `leading_tex`, and `item_open_tex` preserve LaTeX layout and normally should not need editing. All `*_tex` values are inserted as LaTeX, not automatically escaped. Profile rendering validates selected IDs before creating the document.

The initial YAML inventory was mechanically imported with `scripts/import_master_experience.rb` and `scripts/import_master_sections.rb`. Do not rerun those one-time imports after editing YAML: YAML is now the master-history source of truth.

Structured role data lives under `src/data/roles/`.

## ATS résumé default

Edit `src/profiles/resume-ats.yaml` to change the summary, skills, or selected achievement, education, and certification IDs. `achievement_order_from` automatically presents the selected achievement IDs in the order of the master career history, so the ATS résumé does not need a second hand-maintained bullet order. Both documents read contact details from `src/data/contact.yaml`, role titles and technologies from `src/data/roles/`, education from `src/data/sections/education.yaml`, and certification wording from `src/data/sections/credentials_and_continuing_education.yaml`. IBM technologies are stored at the company level in the master history; `company_technologies_from: ibm` displays that list once alongside the first IBM role in the ATS résumé. `src/resume_ats.tex` supplies the plain, single-column layout. `make resume-ats` regenerates the experience, education, and certifications and checks the PDF's extracted page count, section order, employer/title/date sequence, technology text, bullet count, and HSEA omission. The checker uses a generated Swift module cache under `build/generated/`.
