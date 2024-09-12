#
# Build and install code generators and runtime support for generated parsers.
#

PROJECT_ROOT := $(shell pwd)

# Generate this with ./configure
include $(PROJECT_ROOT)/tree-sitter-config.mk

.PHONY: build
build:
	dune build
	test -d bin || { rm -f bin && mkdir bin; }
	ln -sf ../_build/install/default/bin/ocaml-tree-sitter \
	  bin/ocaml-tree-sitter

# Full development setup.
#
.PHONY: setup
setup:
	test -f tree-sitter-version \
	|| cp tree-sitter-version.default tree-sitter-version
	./scripts/check-prerequisites
	./scripts/install-tree-sitter-cli
	./scripts/install-tree-sitter-lib
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
	rm -f config.sh config.mk  # old generated config files
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
