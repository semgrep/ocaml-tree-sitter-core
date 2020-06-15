TESTS = \
  seq \
  choice \
  choice-seq \
  repeat-choice \
  repeat-optional \
  optional-seq \
  opt-repeat1 \
  arithmetic \
  extras \
  backtrack-opt \
  backtrack-repeat \
  backtrack-choice \
  backtrack-multi

# Run all the tests.
.PHONY: test
test:
	../scripts/run-test $(TESTS)

# Remove all the files that are git-ignored.
.PHONY: clean
clean:
	git clean -dfX
