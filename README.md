# Job Search Documents

LaTeX résumé, CV, ATS résumé, abstract, cover letter, and comprehensive master career history.

## Layout

- `src/*.tex`: top-level LaTeX documents.
- `src/content/`: hand-written sections still used by the established résumé, CV, and other documents.
- `src/styles/` and `src/fonts/`: LaTeX class, packages, and fonts.
- `src/data/roles/`: one YAML record per professional role, imported from the master career history.
- `src/data/achievements/`: reusable achievement statements, with stable IDs.
- `src/profiles/`: ordered selections of roles and achievements for particular documents.
- `build/generated/`: generated LaTeX; do not edit it directly.
- `build/pdf/`: final and preview PDFs.
- `private/`: local evidence and notes; excluded from Git.
- `proofs/`: retained page images used for visual review.

The professional-experience part of the master career history is now rendered from YAML. Its previous TeX section remains at `src/content/master_career_history/professional_experience.tex` as an import snapshot, not an active source. The other master-history sections remain hand-written TeX. The established résumé and CV still build from their original sections so their submitted content is preserved during migration; YAML-driven profile builds are available alongside them.

## Build

Requires XeLaTeX, `make`, and Ruby (with its built-in YAML library).

```sh
make                         # established CV, résumé, abstract, and cover letter
make resume cv resume-ats
make master-career-history   # professional experience comes from YAML
make profile PROFILE=healthcare-data-resume
make profile PROFILE=healthcare-data-cv
```

All PDFs are in `build/pdf/`. The two profile examples produce `healthcare-data-resume.pdf` and `healthcare-data-cv.pdf` without replacing `resume.pdf` or `cv.pdf`. `make clean` removes auxiliary files; `make distclean` also removes PDFs.

## Tailor a document

1. Find the role in `src/data/roles/<role-id>.yaml`. Its `achievement_ids` list is the complete inventory for that role.
2. Read the matching statements in `src/data/achievements/<role-id>.yaml`. The `text_tex` field permits LaTeX markup such as `\%` and `\&` and is inserted as LaTeX, so edit it carefully.
3. Copy a profile in `src/profiles/`, give it a new lowercase, hyphenated filename, and choose role order and achievement IDs. A role can use `achievements: all` or omit that field to include every achievement. Optional top-level `headline_tex` and `summary_tex` fields replace the template's headline and summary for that profile.
4. Run `make profile PROFILE=<filename-without-.yaml>` and inspect the PDF.

The `document` field in a profile is `resume` or `cv`. Profile rendering validates role and achievement IDs before creating LaTeX. The initial YAML inventory was mechanically imported from the master history with `scripts/import_master_experience.rb`; do not rerun that one-time import after editing the YAML, because YAML is now the professional-experience source of truth. The master history profile is `src/profiles/master-career-history.yaml`.

The established résumé/CV layouts still use hand-written sections in `src/content/experience/`. New structured role data lives under `src/data/roles/`.
