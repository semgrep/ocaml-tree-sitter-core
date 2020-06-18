#
# Generic makefile to build and test a parser for a specific language.
#

include Makefile.local

PROJECT_ROOT = $(shell git rev-parse --show-toplevel)
DUNE_BIN = $(PROJECT_ROOT)/bin
NODE_BIN = $(PROJECT_ROOT)/node_modules/.bin
SCRIPTS = $(PROJECT_ROOT)/scripts

# Build the parsers.
#
.PHONY: build
build:
	$(MAKE) prep
	$(MAKE) gen-c
	$(MAKE) gen-ocaml
	$(MAKE) build-c
	$(MAKE) build-ocaml

# Run the parsers on the collection of input programs in examples/
#
.PHONY: test
test:
	$(MAKE) parse-step1
	$(MAKE) parse-step2

.PHONY: prep
prep:
	$(SCRIPTS)/prep-lang

.PHONY: gen-c
gen-c:
	$(SCRIPTS)/gen-c

.PHONY: gen-ocaml
gen-ocaml:
	$(SCRIPTS)/gen-ocaml --lang $(LANG)

.PHONY: build-c
build-c:
	$(SCRIPTS)/build-c

.PHONY: build-ocaml
build-ocaml:
	$(SCRIPTS)/build-ocaml

.PHONY: parse-step1
parse-step1:
	$(SCRIPTS)/parse-step1

.PHONY: parse-step2
parse-step2:
	$(SCRIPTS)/parse-step2

.PHONY: stat
stat:
	$(SCRIPTS)/lang-stat projects.txt extensions.txt

.PHONY: clean
clean:
	git clean -dfX
