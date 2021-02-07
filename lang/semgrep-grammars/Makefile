# Build the parsers used by semgrep. The main products are a 'grammar.json'
# file and optionally 'scanner.c' or 'scanner.cc'. 'grammar.json' will
# be reprocessed by ocaml-tree-sitter.
#
.PHONY: build
build:
	make -C src build

# Run parsing tests on our semgrep-* parsers.
.PHONY: test
test:
	make -C src test

.PHONY: clean
clean:
	git clean -dfX
