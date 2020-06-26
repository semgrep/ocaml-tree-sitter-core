#
# Build and install code generators and runtime support for generated parsers.
#
# Building and installing support for specific programming languages is done in
# a second phase, in lang/
#

# Generate this with ./configure
include config.mk

PROJECT_ROOT = $(shell pwd)

TREESITTER_ROOT = \
  $(PROJECT_ROOT)/node_modules/tree-sitter/vendor/tree-sitter/lib

TREESITTER_INCLUDE_DIR = $(TREESITTER_ROOT)/include
export TREESITTER_INCLUDE_DIR

.PHONY: build
build:
	dune build
	test -e bin || ln -s _build/install/default/bin .

# Full development setup
.PHONY: setup
setup:
	./scripts/install-tree-sitter-lib
	./scripts/install-tree-sitter-cli
	opam install --deps-only -y .

# Keep things like node_modules that are worth keeping around
.PHONY: clean
clean:
	rm -rf bin
	dune clean
	make -C tests clean
	make -C lang clean

.PHONY: distclean
distclean:
	# remove everything that's git-ignored
	git clean -dfX

.PHONY: test
test: build
	./_build/default/src/gen/test/test.exe
	./_build/default/src/run/test/test.exe
	$(MAKE) -C tests
	$(MAKE) -C lang build
	$(MAKE) -C lang test

.PHONY: install
install:
	dune install

.PHONY: ci
ci:
	docker build -t ocaml-tree-sitter .
