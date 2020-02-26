all:
	dune build
clean:
	dune clean
test:
	dune runtest
install:
	dune install

run:
	./_build/default/bin/main_codegen.exe -codegen_types tests/arithmetic/grammar.json > tests/arithmetic/ast_arithmetic_output.re

dump:
	./_build/default/bin/main_codegen.exe -parse_grammar tests/arithmetic/grammar.json

.PHONY: all clean install test dump
