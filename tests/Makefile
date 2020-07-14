TESTS = \
  seq \
  choice \
  choice-seq \
  choice-choice \
  repeat-choice \
  repeat-optional \
  optional-seq \
  opt-repeat1 \
  opt-choice-opt \
  recurse \
  arithmetic \
  extras \
  backtrack-opt \
  backtrack-repeat \
  backtrack-choice \
  backtrack-multi

# Build and run all the tests.
.PHONY: test
test:
	$(MAKE) setup
	set -eu; \
	for lang in $(TESTS); do \
	  make -C $$lang; \
	  make -C $$lang test; \
	done

# Generate or update the makefile for each test
.PHONY: setup
setup:
	./setup $(TESTS)

# Remove all the files that are git-ignored.
.PHONY: clean
clean:
	git clean -dfX
