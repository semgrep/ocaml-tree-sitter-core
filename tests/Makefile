# Run all the tests that are supposed to work.
.PHONY: test
test:
	../scripts/run-test arithmetic list_and_option

ALL_TESTS = \
  arithmetic \
  csharp \
  java \
  list_and_option \
  nested \
  ruby \
  rust \
  scala \
  typescript

# Try to run all the tests. Some may be work in progress and may fail.
.PHONY: all
all:
	../scripts/run-test $(ALL_TESTS)

# Remove all the files that are git-ignored.
.PHONY: clean
clean:
	git clean -dfX
