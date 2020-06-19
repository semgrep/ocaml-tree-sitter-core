TESTS = \
  seq \
  choice \
  choice-seq \
  repeat-choice \
  repeat-optional \
  optional-seq \
  opt-repeat1 \
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
	set -eu; \
	for lang in $(TESTS); do \
	  ./setup $$lang; \
	  make -C $$lang; \
	  make -C $$lang test; \
	done

# Remove all the files that are git-ignored.
.PHONY: clean
clean:
	git clean -dfX
