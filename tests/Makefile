SUCCESS_TESTS = \
  seq \
  repeat \
  choice \
  choice-seq \
  repeat-choice \
  repeat-optional \
  optional-seq \
  arithmetic

ALL_TESTS = \
  $(SUCCESS_TESTS) \
  csharp \
  java \
  nested \
  ruby \
  rust \
  scala \
  typescript

# Run all the tests that are supposed to work.
.PHONY: test
test:
	../scripts/run-test $(SUCCESS_TESTS)

# Try to run all the tests. Some may be work in progress and may fail.
.PHONY: all
all:
	../scripts/run-test $(ALL_TESTS)

# Remove all the files that are git-ignored.
.PHONY: clean
clean:
	git clean -dfX
