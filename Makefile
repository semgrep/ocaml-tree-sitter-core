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
	$(MAKE) unit
	$(MAKE) -C tests
	$(MAKE) -C lang build
	$(MAKE) -C lang test

# Run unit tests only.
.PHONY: unit
unit: build
	./_build/default/src/test/test.exe

.PHONY: install
install:
	dune install

.PHONY: ci
ci:
	docker build -t ocaml-tree-sitter .
