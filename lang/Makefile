#
# Build support for the programming languages listed in this folder.
#
# ocaml-tree-sitter must have been built and installed for this to work.
#

# TODO: port to the modern setup: c, cpp
SUPPORTED_LANGUAGES = \
  c-sharp \
  go \
  java \
  javascript \
  kotlin \
  lua \
  r \
  ruby \
  rust \
  tsx \
  typescript

# Languages which are set up to run parsing stats. Ideally, this is all
# the supported languages. See the 'stat' target.
#
STAT_LANGUAGES = \
  c-sharp \
  go \
  java \
  javascript \
  kotlin \
  lua \
  r \
  ruby \
  rust \
  tsx \
  typescript

# Build and test each language. Does not run parsing stats (see 'stat:').
.PHONY: test
test:
	set -e; \
	for lang in $(SUPPORTED_LANGUAGES); do ./test-lang $$lang; done

.PHONY: build
build:
	@echo "'make build' is no longer supported. Use 'make test'."
	exit 1

.PHONY: release
release:
	@echo "'make release' is no longer supported so as to avoid"
	@echo "accidentally pushing changes for other languages."
	@echo "- If you really want to publish changes for all languages,"
	@echo "  use 'make release-all'."
	@echo "- If you want to release just one language named 'foo', run:"
	@echo ""
	@echo "    ./release foo"
	@echo ""
	exit 1

# Place the generated files into their own repo, to be used by an external
# repo as a submodule.
#
.PHONY: release-all
release-all:
	$(MAKE) -C semgrep-grammars
	set -eu; \
        for lang in $(SUPPORTED_LANGUAGES); do ./release $$lang; done

# Make a pretend release.
.PHONY: dry
dry:
	$(MAKE) -C semgrep-grammars
	set -eu; \
        for lang in $(SUPPORTED_LANGUAGES); do ./release $$lang --dry-run; done

# Run parsing stats for each language.
# Each needs a list of projects (projects.txt) and file extensions
# (extensions.txt).
#
.PHONY: stat
stat:
	set -e; \
	for lang in $(STAT_LANGUAGES); do $(MAKE) -C $$lang stat; done
	../scripts/report-stat $(STAT_LANGUAGES) | tee stat.txt

# Run stats on projects-priv.txt instead of projects.txt.
.PHONY: stat-priv
stat-priv:
	set -e; \
	for lang in $(STAT_LANGUAGES); do $(MAKE) -C $$lang stat-priv; done
	../scripts/report-stat $(STAT_LANGUAGES) | tee stat.txt

.PHONY: clean
clean:
	set -e; \
	for lang in $(SUPPORTED_LANGUAGES); do $(MAKE) -C $$lang clean; done
