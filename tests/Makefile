# Run all the tests that are supposed to work.
.PHONY: test
test:
	../scripts/run-test seq repeat choice list_and_option arithmetic

ALL_TESTS = \
  seq \
  repeat \
  choice \
  list_and_option \
  arithmetic \
  csharp \
  java \
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
