#
# Build and install code generators and runtime support for generated parsers.
#

PROJECT_ROOT = $(shell pwd)

TREESITTER_PREFIX ?= $(PROJECT_ROOT)/tree-sitter
TREESITTER_BINDIR ?= $(TREESITTER_PREFIX)/bin
TREESITTER_INCDIR ?= $(TREESITTER_PREFIX)/include
TREESITTER_LIBDIR ?= $(TREESITTER_PREFIX)/lib
export TREESITTER_PREFIX
export TREESITTER_BINDIR
export TREESITTER_INCDIR
export TREESITTER_LIBDIR

.PHONY: build
build:
	dune build
	test -d bin || { rm -f bin && mkdir bin; }
	ln -sf ../_build/install/default/bin/ocaml-tree-sitter \
	  bin/ocaml-tree-sitter

# Full development setup.
#
# Note that the tree-sitter runtime library must be installed in advance,
# prior to calling ./configure.
#
.PHONY: setup
setup:
	./scripts/check-prerequisites
	./scripts/install-tree-sitter-cli
	opam install --deps-only -y .
	opam install ocp-indent

# Shortcut for updating the git submodules.
.PHONY: update
update:
	git submodule update --init --recursive --depth 1

# Keep things like node_modules that are worth keeping around
.PHONY: clean
clean:
	rm -rf bin
	rm -f config.sh config.sh  # retired generated config files
	dune clean
	make -C test clean

.PHONY: distclean
distclean:
	# remove everything that's git-ignored
	git clean -dfX

.PHONY: test
test: build
	$(MAKE) unit
	$(MAKE) e2e

# Run unit tests only (takes a few seconds).
.PHONY: unit
unit: build
	./_build/default/src/test/test.exe

# Run end-to-end tests (takes a few minutes).
.PHONY: e2e
e2e: build
	$(MAKE) -C test

.PHONY: install
install:
	dune install

.PHONY: ci
ci:
	docker build -t ocaml-tree-sitter .
