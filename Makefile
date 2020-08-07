# Build the parsers used by semgrep. The main products are a 'grammar.json'
# file and optionally 'scanner.c' or 'scanner.cc'. 'grammar.json' will
# be reprocessed by ocaml-tree-sitter.
#
.PHONY: build
build:
	make -C src build

# Install the 'tree-sitter' command into node_modules/.bin
.PHONY: setup
setup:
	git submodule update --init --recursive
	which npx || npm install -g npx || sudo npm install -g npx
	npm install tree-sitter@0.16.1 tree-sitter-cli@0.16.9

# Run parsing tests on our semgrep-* parsers.
.PHONY: test
test:
	make -C src test

.PHONY: clean
clean:
	git clean -dfX
