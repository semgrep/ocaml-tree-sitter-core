#
# Build and install code generators and runtime support for generated parsers.
#
# Building and installing support for specific programming languages is done in
# a second phase, in lang/
#

PROJECT_ROOT = $(shell pwd)

TREESITTER_ROOT = \
  $(PROJECT_ROOT)/node_modules/tree-sitter/vendor/tree-sitter/lib

TREESITTER_INCLUDE_DIR = $(TREESITTER_ROOT)/include
TREESITTER_LIBRARY_DIR = $(TREESITTER_ROOT)/lib
export TREESITTER_INCLUDE_DIR
export TREESITTER_LIBRARY_DIR

.PHONY: build
build:
	dune build
	test -e bin || ln -s _build/install/default/bin .

.PHONY: setup
setup:
	./scripts/install-tree-sitter
	opam install --deps-only -y .

# Keep things like node_modules that are worth keeping around
.PHONY: clean
clean:
	rm -rf bin
	dune clean
	make -C tests clean
	make -C lang clean

.PHONY: distclean
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
