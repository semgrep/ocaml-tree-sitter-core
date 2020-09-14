#
# Build and install code generators and runtime support for generated parsers.
#
# Building and installing support for specific programming languages is done in
# a second phase, in lang/
#

# Generate this with ./configure
include config.mk

PROJECT_ROOT = $(shell pwd)

.PHONY: build
build:
	dune build
	test -e bin || ln -s _build/install/default/bin .

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

# Shortcut for updating the git submodules.
.PHONY: update
update:
	git submodule update --init --recursive

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
	$(MAKE) unit
	$(MAKE) e2e

# Run unit tests only (takes a few seconds).
.PHONY: unit
unit: build
	./_build/default/src/test/test.exe

# Run end-to-end tests (takes a few minutes).
.PHONY: e2e
e2e: build
	$(MAKE) -C tests

# Build and test all the production languages.
.PHONY: lang
lang: build
	$(MAKE) -C lang build
	$(MAKE) -C lang test

# Run parsing stats for the supported languages in lang/.
.PHONY: stat
stat:
	$(MAKE) -C lang build
	$(MAKE) -C lang stat

.PHONY: install
install:
	dune install

.PHONY: ci
ci:
	docker build -t ocaml-tree-sitter .
