PROJECT_ROOT = $(shell git rev-parse --show-toplevel)

# Node packages provided as git submodules.
TREE_SITTER_PACKAGES = \
  tree-sitter-c-sharp \
  tree-sitter-javascript \
  tree-sitter-kotlin \
  tree-sitter-ruby \
  tree-sitter-typescript

# Semgrep extensions of the tree-sitter-* packages.
SEMGREP_PACKAGES = \
  semgrep-c-sharp \
  semgrep-javascript \
  semgrep-kotlin \
  semgrep-ruby \
  semgrep-typescript

.PHONY: build
build:
	$(MAKE) build-tree-sitter
	$(MAKE) build-semgrep

# Install node modules required by the semgrep-* packages.
.PHONY: build-tree-sitter
build-tree-sitter:
	set -e; \
	for pkg in $(TREE_SITTER_PACKAGES); do \
	  echo "Install $$pkg"; \
	  (cd $(PROJECT_ROOT) && npm install src/$$pkg); \
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
