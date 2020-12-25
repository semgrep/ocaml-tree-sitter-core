#
# Build support for the programming languages listed in this folder.
#
# ocaml-tree-sitter must have been built and installed for this to work.
#

SUPPORTED_LANGUAGES = \
  c \
  cpp \
  c-sharp \
  go \
  java \
  javascript \
  lua \
  ruby \
  tsx \
  typescript \
  kotlin

# Languages which are set up to run parsing stats. Ideally, this is all
# the supported languages. See the 'stat' target.
#
STAT_LANGUAGES = \
  c-sharp \
  go \
  java \
  javascript \
  lua \
  ruby \
  tsx \
  typescript \
  kotlin

.PHONY: build
build:
	$(MAKE) -C semgrep-grammars
	set -e; \
	for lang in $(SUPPORTED_LANGUAGES); do $(MAKE) -C $$lang build; done

.PHONY: install
install:
	set -e; \
	for lang in $(SUPPORTED_LANGUAGES); do $(MAKE) -C $$lang install; done

.PHONY: test
test:
	set -e; \
	for lang in $(SUPPORTED_LANGUAGES); do $(MAKE) -C $$lang test; done

# Place the generated files into their own repo, to be used by an external
# repo as a submodule.
#
.PHONY: release
release:
	@test -z "$$(git status --porcelain)" \
	|| (echo "Commit your work or use 'make dry'."; exit 1)
	$(MAKE) -C semgrep-grammars
	./release $(SUPPORTED_LANGUAGES)

# Make a pretend release.
.PHONY: dry
dry:
	$(MAKE) -C semgrep-grammars
	./release --dry-run $(SUPPORTED_LANGUAGES)

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
