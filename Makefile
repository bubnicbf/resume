ENGINE   := xelatex
SRC_DIR  := src
OUT_DIR  := output
ATS_OUT_DIR := $(OUT_DIR)/pdf

DOCS     := cv abstract resume cover
PDFS     := $(DOCS:%=$(OUT_DIR)/%.pdf)

CONTENT_TEX := $(wildcard content/*.tex) \
               $(wildcard content/summary/*.tex) \
               $(wildcard content/exerience/*.tex) \
               $(wildcard content/education/*.tex) \
               $(wildcard content/publication/*.tex)

STYLE_FILES := $(wildcard styles/*.cls) \
               $(wildcard styles/*.sty)

SRC_FILES := $(wildcard src/*.tex)

COMMON_DEPS := $(CONTENT_TEX) $(STYLE_FILES)

XELATEX_FLAGS := -synctex=1 -interaction=nonstopmode -file-line-error \
                 -output-directory=../$(OUT_DIR)

.PHONY: all cv abstract resume resume-ats resume-arcadia cover cover-arcadia clean distclean open

all: $(PDFS)

cv: $(OUT_DIR)/cv.pdf
abstract: $(OUT_DIR)/abstract.pdf
resume: $(OUT_DIR)/resume.pdf
resume-ats: $(ATS_OUT_DIR)/resume_ats.pdf
resume-arcadia: $(ATS_OUT_DIR)/ben_bubnick_arcadia_resume.pdf
cover: $(OUT_DIR)/cover.pdf
cover-arcadia: $(ATS_OUT_DIR)/ben_bubnick_arcadia_cover_letter.pdf

open: $(OUT_DIR)/resume.pdf
	open "$(OUT_DIR)/resume.pdf"

$(OUT_DIR)/cv.pdf: $(SRC_DIR)/cv.tex $(COMMON_DEPS)
	@mkdir -p "$(OUT_DIR)"
	@echo "==> Building cv"
	@cd "$(SRC_DIR)" && $(ENGINE) $(XELATEX_FLAGS) "cv.tex"
	@cd "$(SRC_DIR)" && $(ENGINE) $(XELATEX_FLAGS) "cv.tex"
	@echo "==> Wrote $(OUT_DIR)/cv.pdf"

$(OUT_DIR)/resume.pdf: $(SRC_DIR)/resume.tex $(COMMON_DEPS)
	@mkdir -p "$(OUT_DIR)"
	@echo "==> Building resume"
	@cd "$(SRC_DIR)" && $(ENGINE) $(XELATEX_FLAGS) "resume.tex"
	@cd "$(SRC_DIR)" && $(ENGINE) $(XELATEX_FLAGS) "resume.tex"
	@echo "==> Wrote $(OUT_DIR)/resume.pdf"

$(ATS_OUT_DIR)/resume_ats.pdf: $(SRC_DIR)/resume_ats.tex
	@mkdir -p "$(ATS_OUT_DIR)"
	@echo "==> Building ATS resume"
	@cd "$(SRC_DIR)" && $(ENGINE) $(XELATEX_FLAGS) -output-directory=../$(ATS_OUT_DIR) "resume_ats.tex"
	@cd "$(SRC_DIR)" && $(ENGINE) $(XELATEX_FLAGS) -output-directory=../$(ATS_OUT_DIR) "resume_ats.tex"
	@echo "==> Wrote $(ATS_OUT_DIR)/resume_ats.pdf"

$(ATS_OUT_DIR)/ben_bubnick_arcadia_resume.pdf: $(SRC_DIR)/resume_arcadia.tex
	@mkdir -p "$(ATS_OUT_DIR)"
	@echo "==> Building Arcadia resume"
	@cd "$(SRC_DIR)" && $(ENGINE) $(XELATEX_FLAGS) -jobname=ben_bubnick_arcadia_resume -output-directory=../$(ATS_OUT_DIR) "resume_arcadia.tex"
	@cd "$(SRC_DIR)" && $(ENGINE) $(XELATEX_FLAGS) -jobname=ben_bubnick_arcadia_resume -output-directory=../$(ATS_OUT_DIR) "resume_arcadia.tex"
	@echo "==> Wrote $(ATS_OUT_DIR)/ben_bubnick_arcadia_resume.pdf"

$(ATS_OUT_DIR)/ben_bubnick_arcadia_cover_letter.pdf: $(SRC_DIR)/cover_arcadia.tex
	@mkdir -p "$(ATS_OUT_DIR)"
	@echo "==> Building Arcadia cover letter"
	@cd "$(SRC_DIR)" && $(ENGINE) $(XELATEX_FLAGS) -jobname=ben_bubnick_arcadia_cover_letter -output-directory=../$(ATS_OUT_DIR) "cover_arcadia.tex"
	@cd "$(SRC_DIR)" && $(ENGINE) $(XELATEX_FLAGS) -jobname=ben_bubnick_arcadia_cover_letter -output-directory=../$(ATS_OUT_DIR) "cover_arcadia.tex"
	@echo "==> Wrote $(ATS_OUT_DIR)/ben_bubnick_arcadia_cover_letter.pdf"

$(OUT_DIR)/abstract.pdf: $(SRC_DIR)/abstract.tex $(COMMON_DEPS)
	@mkdir -p "$(OUT_DIR)"
	@echo "==> Building abstract"
	@cd "$(SRC_DIR)" && $(ENGINE) $(XELATEX_FLAGS) "abstract.tex"
	@cd "$(SRC_DIR)" && $(ENGINE) $(XELATEX_FLAGS) "abstract.tex"
	@echo "==> Wrote $(OUT_DIR)/abstract.pdf"

$(OUT_DIR)/cover.pdf: $(SRC_DIR)/cover.tex $(COMMON_DEPS)
	@mkdir -p "$(OUT_DIR)"
	@echo "==> Building cover"
	@cd "$(SRC_DIR)" && $(ENGINE) $(XELATEX_FLAGS) "cover.tex"
	@cd "$(SRC_DIR)" && $(ENGINE) $(XELATEX_FLAGS) "cover.tex"
	@echo "==> Wrote $(OUT_DIR)/cover.pdf"

clean:
	@echo "==> Cleaning aux/log files from $(OUT_DIR)"
	@rm -f $(OUT_DIR)/*.aux \
	       $(OUT_DIR)/*.log \
	       $(OUT_DIR)/*.out \
	       $(OUT_DIR)/*.toc \
	       $(OUT_DIR)/*.synctex.gz \
	       $(OUT_DIR)/*.nav \
	       $(OUT_DIR)/*.snm \
	       $(OUT_DIR)/*.fls \
	       $(OUT_DIR)/*.fdb_latexmk
	@rm -f $(ATS_OUT_DIR)/*.aux \
	       $(ATS_OUT_DIR)/*.log \
	       $(ATS_OUT_DIR)/*.out \
	       $(ATS_OUT_DIR)/*.toc \
	       $(ATS_OUT_DIR)/*.synctex.gz

distclean: clean
	@echo "==> Removing PDFs from $(OUT_DIR)"
	@rm -f $(OUT_DIR)/*.pdf
	@rm -f $(ATS_OUT_DIR)/*.pdf
