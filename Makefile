ENGINE   := xelatex
SRC_DIR  := src
OUT_DIR  := build/pdf
ROLE_DATA_YAML := $(wildcard src/data/roles/*.yaml) $(wildcard src/data/achievements/*.yaml)
DATA_YAML := $(ROLE_DATA_YAML) $(wildcard src/data/sections/*.yaml)

XELATEX_FLAGS := -synctex=1 -interaction=nonstopmode -file-line-error \
                 -output-directory=../$(OUT_DIR)

.PHONY: all resume master-career-history clean distclean open

all: resume master-career-history

resume: $(OUT_DIR)/resume.pdf
master-career-history: $(OUT_DIR)/master_career_history.pdf

open: $(OUT_DIR)/resume.pdf
	open "$(OUT_DIR)/resume.pdf"

$(OUT_DIR)/resume.pdf: $(SRC_DIR)/resume.tex $(ROLE_DATA_YAML) src/data/contact.yaml src/data/sections/education.yaml src/data/sections/credentials_and_continuing_education.yaml src/profiles/resume.yaml src/profiles/master-career-history.yaml scripts/render_profile.rb scripts/check_resume.rb scripts/extract_pdf_text.swift
	@mkdir -p "$(OUT_DIR)"
	@ruby scripts/render_profile.rb resume
	@echo "==> Building resume"
	@cd "$(SRC_DIR)" && $(ENGINE) $(XELATEX_FLAGS) "resume.tex"
	@cd "$(SRC_DIR)" && $(ENGINE) $(XELATEX_FLAGS) "resume.tex"
	@ruby scripts/check_resume.rb
	@echo "==> Wrote $(OUT_DIR)/resume.pdf"

$(OUT_DIR)/master_career_history.pdf: $(SRC_DIR)/master_career_history.tex $(DATA_YAML) src/data/contact.yaml src/profiles/master-career-history.yaml scripts/render_profile.rb
	@mkdir -p "$(OUT_DIR)"
	@ruby scripts/render_profile.rb master-career-history
	@echo "==> Building master career history"
	@cd "$(SRC_DIR)" && $(ENGINE) $(XELATEX_FLAGS) "master_career_history.tex"
	@cd "$(SRC_DIR)" && $(ENGINE) $(XELATEX_FLAGS) "master_career_history.tex"
	@echo "==> Wrote $(OUT_DIR)/master_career_history.pdf"

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
