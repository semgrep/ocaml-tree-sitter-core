# List of tests that run by default and are expected to pass.
#
TESTS = \
  seq \
  weird-names \
  choice \
  choice-seq \
  repeat-choice \
  opt-repeat1 \
  recurse \
  arithmetic \
  extras \
  backtrack \
  token \
  anon-pat \
  prec \
  ignore-error \
  pattern \
  inline-token \
  explicit-extra \
  reserved \
  inline

# Build and run all the tests.
.PHONY: test
test:
	$(MAKE) setup
	set -eu; \
	for lang in $(TESTS); do \
	  $(MAKE) -C $$lang; \
	  $(MAKE) -C $$lang test; \
	done

# Generate or update the makefile for each test
.PHONY: setup
setup:
	./setup $(TESTS)

# Remove all the files that are git-ignored.
.PHONY: clean
clean:
	git clean -dfX
