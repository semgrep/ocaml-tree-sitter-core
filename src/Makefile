PROJECT_ROOT = $(shell git rev-parse --show-toplevel)
TREE_SITTER = npx tree-sitter

# Node packages provided as git submodules.
TREE_SITTER_PACKAGES = \
  tree-sitter-javascript \
  tree-sitter-typescript

SEMGREP_PACKAGES = \
  semgrep-typescript

PACKAGES = $(TREE_SITTER_PACKAGES) $(SEMGREP_PACKAGES)

# Folders containing a 'grammar.js' and optionally 'src/scanner.cc?'
# Those grammars are used by semgrep directly. They depend on the
# community tree-sitter-* projects.
#
SEMGREP_LANGUAGES = \
  semgrep-typescript/typescript

.PHONY: build
build:
	$(MAKE) build-tree-sitter
	$(MAKE) build-semgrep

# Install node modules required by the semgrep-* packages.
.PHONY: build-tree-sitter
build-tree-sitter:
	for pkg in $(TREE_SITTER_PACKAGES); do \
	  echo "Install $$pkg"; \
	  (cd $(PROJECT_ROOT) && npm install src/$$pkg); \
	done

# Generate parsers for the semgrep-* packages.
.PHONY: build-semgrep
build-semgrep:
	for pkg in $(SEMGREP_PACKAGES); do \
	  echo "Build $$pkg"; \
	  $(MAKE) -C $$pkg build; \
	done

# Test the semgrep-* packages.
.PHONY: test
test:
	for pkg in $(SEMGREP_PACKAGES); do \
	  echo "Test $$pkg"; \
	  $(MAKE) -C $$pkg test; \
	done

.PHONY: clean
clean:
	git clean -dfX
