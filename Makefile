# Makefile for pdf-deflyt project + DEVONthink scripts
# Typical use
# cd pdf-deflyt
# make install-bin        # installs ./pdf-deflyt → ~/bin/pdf-deflyt (default)
# make compile            # compiles .applescript → .scpt into devonthink-scripts/compiled
# make install-dt         # copies compiled .scpt into DEVONthink's App Scripts folder
# or do both:
# make install            # = install-bin + install-dt
SHELL := /bin/bash

REPO_ROOT      := $(CURDIR)
SRC_DIR        := devonthink-scripts/src
COMPILED_DIR   := devonthink-scripts/compiled
ASSETS_DIR     := tests/assets
SMOKE_DIR      := tests/assets-smoke
BUILD_DIR      := tests/build

# DEVONthink version: 4 (default) or 3
DT_VER ?= 4

# Destination for pdf-deflyt
BIN_DIR ?= $(HOME)/bin

ifeq ($(DT_VER),4)
DT_BUNDLE := com.devon-technologies.think
else ifeq ($(DT_VER),3)
DT_BUNDLE := com.devon-technologies.think3
else
$(error DT_VER must be 3 or 4)
endif

DT_SCRIPTS_DIR := $(HOME)/Library/Application Scripts/$(DT_BUNDLE)
DT_MENU    := $(DT_SCRIPTS_DIR)/Menu
DT_RULES   := $(DT_SCRIPTS_DIR)/Smart Rules
DT_MENU_SCRIPT := Compress PDF Now.scpt
DT_RULE_SCRIPT := Compress PDF (Smart Rule).scpt

.PHONY: compile clean show-paths test test-clean install-bin install-dt uninstall-dt install lint smoke smoke-clean fmt benchmark

.DEFAULT_GOAL := help

.PHONY: help
help:
	@echo "Targets:"
	@echo "  install-bin   Install ./pdf-deflyt -> ~/bin/pdf-deflyt"
	@echo "  compile       Compile AppleScripts -> devonthink-scripts/compiled"
	@echo "  install-dt    Copy compiled .scpt into DEVONthink App Scripts"
	@echo "  install       install-bin + install-dt"
	@echo "  test          Run test suite"
	@echo "  test-clean    Clean test artifacts"
	@echo "  benchmark     Run performance benchmarks"
	@echo "  smoke         Run smoke tests (lightweight)"
	@echo "  lint          Check code style"
	@echo "  fmt           Format code"
	@echo "  clean         Remove compiled scripts"
	@echo "  show-paths    Print important paths"


# Convenience: install both the CLI and DEVONthink scripts
install: install-bin install-dt

show-paths:
	@echo "SRC_DIR:        $(SRC_DIR)"
	@echo "COMPILED_DIR:   $(COMPILED_DIR)"
	@echo "DT_VER:         $(DT_VER)"
	@echo "DT_SCRIPTS_DIR: $(DT_SCRIPTS_DIR)"

compile:
	@set -euo pipefail; \
	mkdir -p "$(COMPILED_DIR)"; \
	found=0; \
	while IFS= read -r -d '' f; do \
	  found=1; \
	  base="$${f##*/}"; \
	  out="$(COMPILED_DIR)/$${base%.applescript}.scpt"; \
	  echo "Compiling: $$f -> $$out"; \
	  osacompile -l AppleScript -o "$$out" "$$f"; \
	done < <(find "$(SRC_DIR)" -type f -name '*.applescript' -print0); \
	if [[ $$found -eq 0 ]]; then \
	  echo "No .applescript files found in $(SRC_DIR)"; \
	fi

install-dt: compile
	@mkdir -p "$(DT_MENU)" "$(DT_RULES)"
	@echo "Installing scripts:"
	@rm -f "$(DT_MENU)/$(DT_MENU_SCRIPT)" \
	       "$(DT_MENU)/pdf-deflyt Compress PDF Now.scpt" \
	       "$(DT_MENU)/pdf-deflyt DT4 Compress PDF Now.scpt" \
	       "$(DT_MENU)/pdf-deflyt DT4 v3 Compress PDF Now.scpt" \
	       "$(DT_RULES)/$(DT_RULE_SCRIPT)" \
	       "$(DT_RULES)/pdf-deflyt Compress PDF (Smart Rule).scpt" \
	       "$(DT_RULES)/pdf-deflyt DT4 Compress PDF (Smart Rule).scpt" \
	       "$(DT_RULES)/pdf-deflyt DT4 v3 Compress PDF (Smart Rule).scpt"
	@if [ -f "$(COMPILED_DIR)/$(DT_MENU_SCRIPT)" ]; then \
		cp -f "$(COMPILED_DIR)/$(DT_MENU_SCRIPT)" "$(DT_MENU)/$(DT_MENU_SCRIPT)"; \
		echo "  ✓ $(DT_MENU_SCRIPT) → Menu"; \
	fi
	@if [ -f "$(COMPILED_DIR)/$(DT_RULE_SCRIPT)" ]; then \
		cp -f "$(COMPILED_DIR)/$(DT_RULE_SCRIPT)" "$(DT_RULES)/$(DT_RULE_SCRIPT)"; \
		echo "  ✓ $(DT_RULE_SCRIPT) → Smart Rules"; \
	fi
	@echo "Done: installed to DEVONthink scripts folders."

uninstall-dt:
	@rm -f "$(DT_MENU)/$(DT_MENU_SCRIPT)" \
	       "$(DT_MENU)/pdf-deflyt Compress PDF Now.scpt" \
	       "$(DT_MENU)/pdf-deflyt DT4 Compress PDF Now.scpt" \
	       "$(DT_MENU)/pdf-deflyt DT4 v3 Compress PDF Now.scpt" \
	       "$(DT_RULES)/$(DT_RULE_SCRIPT)" \
	       "$(DT_RULES)/pdf-deflyt Compress PDF (Smart Rule).scpt" \
	       "$(DT_RULES)/pdf-deflyt DT4 Compress PDF (Smart Rule).scpt" \
	       "$(DT_RULES)/pdf-deflyt DT4 v3 Compress PDF (Smart Rule).scpt" || true
	@echo "Removed DT scripts from:"
	@echo "  • $(DT_MENU)"
	@echo "  • $(DT_RULES)"

# Install pdf-deflyt into ~/bin (create if missing)
install-bin:
	@mkdir -p "$(BIN_DIR)"
	@install -m 0755 pdf-deflyt "$(BIN_DIR)/pdf-deflyt"
	@install -m 0755 pdf-deflyt-image-recompress "$(BIN_DIR)/pdf-deflyt-image-recompress"
	@echo "Installed to $(BIN_DIR)/pdf-deflyt"
	@echo "Installed to $(BIN_DIR)/pdf-deflyt-image-recompress"
	@case ":$(PATH):" in *:"$(BIN_DIR)":*) ;; *) echo 'NOTE: add $(BIN_DIR) to your PATH';; esac

clean:
	@rm -rf "$(COMPILED_DIR)" "$(ASSETS_DIR)" "$(SMOKE_DIR)" "$(BUILD_DIR)"
	@echo "Removed compiled scripts, test assets, smoke assets, and build output."
	
test-clean: clean
	@mkdir -p "$(BUILD_DIR)" "$(ASSETS_DIR)"
	@echo "Test environment reset: rebuilt $(BUILD_DIR) and $(ASSETS_DIR)."
		
# Run the full test suite from a clean slate
test: test-clean
	@echo "🔄 Rebuilding fixtures..."
	@PDF_DEFLYT_TEST_ROOT="$(CURDIR)" \
	  PDF_DEFLYT_BUILD_DIR="$(CURDIR)/tests/build" \
	  PDF_DEFLYT_ASSETS_DIR="$(CURDIR)/tests/assets" \
	  tests/fixtures.sh
	@echo "✅ Fixtures ready."
	@echo "🚀 Running full test suite..."
	@PDF_DEFLYT_TEST_ROOT="$(CURDIR)" \
	  PDF_DEFLYT_BUILD_DIR="$(CURDIR)/tests/build" \
	  PDF_DEFLYT_ASSETS_DIR="$(CURDIR)/tests/assets" \
	  tests/run.sh
	
smoke-clean:
	@rm -rf "$(SMOKE_DIR)"
	@mkdir -p "$(SMOKE_DIR)"
	@echo "Removed and recreated $(SMOKE_DIR)"
	
# Run only the smoke tests (lightweight)
smoke: smoke-clean
	@echo "🔄 Preparing smoke test environment..."
	@tests/smoke.sh

lint:
	@VERBOSE=$(VERBOSE) FIX=$(FIX) bash scripts/lint.sh

fmt:
	@scripts/format.sh

# Run performance benchmarks
benchmark:
	@echo "🚀 Running performance benchmarks..."
	@tests/benchmark.sh
