ENGINE   := xelatex
SRC_DIR  := src
OUT_DIR  := build/pdf
ATS_OUT_DIR := $(OUT_DIR)

DOCS     := cv abstract resume cover
PDFS     := $(DOCS:%=$(OUT_DIR)/%.pdf)

CONTENT_TEX := $(wildcard src/content/*.tex) \
               $(wildcard src/content/summary/*.tex) \
               $(wildcard src/content/experience/*.tex) \
               $(wildcard src/content/education/*.tex) \
               $(wildcard src/content/publication/*.tex)

STYLE_FILES := $(wildcard src/styles/*.cls) \
               $(wildcard src/styles/*.sty)

SRC_FILES := $(wildcard src/*.tex)
DATA_YAML := $(wildcard src/data/roles/*.yaml) $(wildcard src/data/achievements/*.yaml)
PROFILE ?= healthcare-data-resume

COMMON_DEPS := $(CONTENT_TEX) $(STYLE_FILES)

MASTER_CAREER_HISTORY_CONTENT := \
               $(wildcard src/content/master_career_history/*.tex)

XELATEX_FLAGS := -synctex=1 -interaction=nonstopmode -file-line-error \
                 -output-directory=../$(OUT_DIR)

.PHONY: all cv abstract resume resume-ats master-career-history resume-arcadia cover cover-arcadia profile clean distclean open

all: $(PDFS)

cv: $(OUT_DIR)/cv.pdf
abstract: $(OUT_DIR)/abstract.pdf
resume: $(OUT_DIR)/resume.pdf
resume-ats: $(ATS_OUT_DIR)/resume_ats.pdf
master-career-history: $(ATS_OUT_DIR)/master_career_history.pdf
resume-arcadia: $(ATS_OUT_DIR)/ben_bubnick_arcadia_resume.pdf
cover: $(OUT_DIR)/cover.pdf
cover-arcadia: $(ATS_OUT_DIR)/ben_bubnick_arcadia_cover_letter.pdf

# Preview a YAML-driven resume or CV without replacing the established PDFs.
# Example: make profile PROFILE=healthcare-data-resume
profile:
	@ruby scripts/render_profile.rb "$(PROFILE)"
	@mkdir -p "$(ATS_OUT_DIR)"
	@cd "$(SRC_DIR)" && $(ENGINE) $(XELATEX_FLAGS) -jobname="$(PROFILE)" -output-directory=../$(ATS_OUT_DIR) "../build/generated/$(PROFILE).tex"
	@cd "$(SRC_DIR)" && $(ENGINE) $(XELATEX_FLAGS) -jobname="$(PROFILE)" -output-directory=../$(ATS_OUT_DIR) "../build/generated/$(PROFILE).tex"

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

$(ATS_OUT_DIR)/master_career_history.pdf: $(SRC_DIR)/master_career_history.tex $(MASTER_CAREER_HISTORY_CONTENT) $(DATA_YAML) src/profiles/master-career-history.yaml scripts/render_profile.rb
	@mkdir -p "$(ATS_OUT_DIR)"
	@ruby scripts/render_profile.rb master-career-history
	@echo "==> Building master career history"
	@cd "$(SRC_DIR)" && $(ENGINE) $(XELATEX_FLAGS) -output-directory=../$(ATS_OUT_DIR) "master_career_history.tex"
	@cd "$(SRC_DIR)" && $(ENGINE) $(XELATEX_FLAGS) -output-directory=../$(ATS_OUT_DIR) "master_career_history.tex"
	@echo "==> Wrote $(ATS_OUT_DIR)/master_career_history.pdf"

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

distclean: clean
	@echo "==> Removing PDFs from $(OUT_DIR)"
	@rm -f $(OUT_DIR)/*.pdf
