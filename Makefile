# Makefile for bash-gitaware v2.
#
# Targets:
#   build   Regenerate new.bashrc from lib/*.bash via bin/build.sh.
#   test    Run the test suite (M1.4 will populate tests/).
#   lint    Run shellcheck on lib/, bin/, scripts.
#   check   Verify new.bashrc is up to date with lib/ (the CI gate).
#   demo    Regenerate the vhs demo (M6 lands the tape).
#   clean   Remove build leftovers.

.PHONY: build test lint check demo clean

build:
	@bash bin/build.sh

test:
	@if [ -x tests/run.sh ]; then bash tests/run.sh; else echo "no tests yet (M1.4)"; fi

lint: build
	@command -v shellcheck >/dev/null 2>&1 || { echo "shellcheck not installed"; exit 1; }
	@shellcheck -x new.bashrc bin/*.sh tests/*.sh

check: build
	@if ! git diff --exit-code -- new.bashrc >/dev/null 2>&1; then \
	  echo "new.bashrc is out of date -- run 'make build' and commit the result"; \
	  exit 1; \
	fi
	@echo "new.bashrc is up to date"

demo:
	@if [ -f demo/demo.tape ]; then \
	  command -v vhs >/dev/null 2>&1 || { echo "vhs not installed (charmbracelet/vhs)"; exit 1; }; \
	  vhs demo/demo.tape; \
	else \
	  echo "no demo yet (M6)"; \
	fi

clean:
	@rm -f new.bashrc.tmp
