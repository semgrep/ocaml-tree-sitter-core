#
# Build support for the programming languages listed in this folder.
#
# ocaml-tree-sitter must have been built and installed for this to work.
#

SUPPORTED_LANGUAGES = \
  c \
  cpp \
  go \
  java \
  javascript \
  ruby \
  typescript

.PHONY: build
build:
	for lang in $(SUPPORTED_LANGUAGES); do $(MAKE) -C $$lang build; done

.PHONY: install
install:
	for lang in $(SUPPORTED_LANGUAGES); do $(MAKE) -C $$lang install; done

.PHONY: test
test:
	for lang in $(SUPPORTED_LANGUAGES); do $(MAKE) -C $$lang test; done

# Place the generated files into their own repo, to be used by an external
# repo as a submodule.
#
.PHONY: release
release:
	./release $(SUPPORTED_LANGUAGES)

.PHONY: clean
clean:
	for lang in $(SUPPORTED_LANGUAGES); do $(MAKE) -C $$lang clean; done
