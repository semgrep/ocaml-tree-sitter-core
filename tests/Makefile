SUCCESS_TESTS = \
  seq \
  repeat \
  choice \
  choice-seq \
  repeat-choice \
  repeat-optional \
  optional-seq \
  opt-repeat1 \
  arithmetic \
  name-alias \
  string-alias \
  alias-scope \
  inline-alias \
  unhide-token \
  extras

ALL_TESTS = \
  $(SUCCESS_TESTS) \
  hide-token \
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
