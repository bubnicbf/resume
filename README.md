# Job Search

This repository contains my resume, CV, and abstract, all built with LaTeX.

## Documents

- [Resume (2 pages)](https://github.com/bubnicbf/job_search/raw/master/output/resume.pdf)
- ATS resume (2 pages): `output/pdf/resume_ats.pdf`
- [Abstract (1 page)](https://github.com/bubnicbf/job_search/raw/master/output/abstract.pdf)
- [Full CV (4 pages)](https://github.com/bubnicbf/job_search/raw/master/output/cv.pdf)

---

## Build Instructions

This project includes a `Makefile` to simplify building all documents with **XeLaTeX**.

### Requirements
- [XeLaTeX](https://tug.org/xetex/) (available through TeX Live or MiKTeX)
- `make` (built in on macOS/Linux, installable on Windows via WSL or Git Bash)

### Usage

From the repository root:

- **Build everything (CV, resume, abstract):**
```bash
  make
```

- **Build a specific document:**
```bash
  make cv
  make resume
  make resume-ats
  make abstract
```

- **Force Build a specific document:**
```bash
  make -B cv
  make -B resume
  make -B resume-ats
  make -B abstract
```

- **Open the résumé PDF (macOS only):**
```bash
  make open
```

- **Clean build artifacts (logs, aux files, etc.), keep PDFs:**
```bash
  make clean
```

- **Clean build artifacts and PDFs:**
```bash
  make distclean
```

### Outputs

- Standard PDFs are written to `output/`; the ATS resume is written to `output/pdf/`.

- Auxiliary build artifacts (`.aux`, `.log`, `.out`, etc.) are written alongside the PDFs and removed by `make clean`.
