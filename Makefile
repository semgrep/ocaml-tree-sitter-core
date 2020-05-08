build:
	dune build

clean:
	dune clean

test: build
	./scripts/run-test

install:
	dune install

run:
	./_build/install/default/bin/prts tests/arithmetic/grammar.json \
	> tests/arithmetic/ast_arithmetic_output.re

.PHONY: build clean install test
