PROJECT_ROOT = $(shell git rev-parse --show-toplevel)

# Node packages provided as git submodules.
TREE_SITTER_PACKAGES = \
  tree-sitter-c-sharp \
  tree-sitter-javascript \
  tree-sitter-kotlin \
  tree-sitter-lua \
  tree-sitter-ruby \
  tree-sitter-rust \
  tree-sitter-typescript

# Semgrep extensions of the tree-sitter-* packages.
SEMGREP_PACKAGES = \
  semgrep-c-sharp \
  semgrep-javascript \
  semgrep-kotlin \
  semgrep-lua \
  semgrep-ruby \
  semgrep-rust \
  semgrep-typescript

.PHONY: build
build:
	$(MAKE) check-submodules
	$(MAKE) build-tree-sitter
	$(MAKE) build-semgrep

# Sanity check before running npm install.
.PHONY: check-submodules
check-submodules:
	set -e ; \
	for pkg in $(TREE_SITTER_PACKAGES); do \
	  echo "Check submodule $$pkg"; \
	  if ! test -f "$$pkg"/package.json; then \
	    echo "Missing $$pkg/package.json." >&2; \
	    echo "Make sure you ran the following:" >&2; \
	    echo "  git submodule update --init --recursive" >&2; \
	    exit 1; \
	  fi; \
	done

# Install node modules required by the semgrep-* packages.
.PHONY: build-tree-sitter
build-tree-sitter:
	set -e; \
	for pkg in $(TREE_SITTER_PACKAGES); do \
	  echo "Install $$pkg"; \
	  (cd $(PROJECT_ROOT) && npm install ./src/$$pkg); \
	done

# Generate parsers for the semgrep-* packages.
.PHONY: build-semgrep
build-semgrep:
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
