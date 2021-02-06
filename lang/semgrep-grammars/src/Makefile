PROJECT_ROOT = $(shell git rev-parse --show-toplevel)

# Semgrep extensions of the tree-sitter-* packages.
SEMGREP_PACKAGES = \
  semgrep-c-sharp \
  semgrep-javascript \
  semgrep-kotlin \
  semgrep-lua \
  semgrep-r \
  semgrep-ruby \
  semgrep-rust \
  semgrep-typescript

# Generate parsers for the semgrep-* packages.
.PHONY: build
build:
	set -e; \
	for pkg in $(SEMGREP_PACKAGES); do \
	  echo "Build $$pkg"; \
	  $(MAKE) -C $$pkg build; \
	done

# Test the semgrep-* packages.
.PHONY: test
test:
	set -e; \
	for pkg in $(SEMGREP_PACKAGES); do \
	  echo "Test $$pkg"; \
	  $(MAKE) -C $$pkg test; \
	done

.PHONY: clean
clean:
	git clean -dfX
