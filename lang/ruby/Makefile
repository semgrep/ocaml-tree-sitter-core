PROJECT_ROOT = $(shell git rev-parse --show-toplevel)
DUNE_BIN = $(PROJECT_ROOT)/bin
NODE_BIN = $(PROJECT_ROOT)/node_modules/.bin
SCRIPTS = $(PROJECT_ROOT)/scripts

.PHONY: build
build:
	$(MAKE) prep
	$(MAKE) gen-c
	$(MAKE) gen-ocaml
	$(MAKE) build-c
	$(MAKE) build-ocaml

.PHONY: prep
prep:
	$(SCRIPTS)/prep-lang

.PHONY: gen-c
gen-c:
	$(SCRIPTS)/gen-c

.PHONY: gen-ocaml
gen-ocaml:
	$(SCRIPTS)/gen-ocaml

.PHONY: build-c
build-c:
	$(SCRIPTS)/build-c

.PHONY: build-ocaml
build-ocaml:
	$(SCRIPTS)/build-ocaml
