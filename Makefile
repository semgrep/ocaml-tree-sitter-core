all:
	dune build
clean:
	dune clean
test:
	dune runtest
install:
	dune install

dump:
	./_build/default/bin/main_codegen.exe -parse_grammar tests/arithmetic/grammar.json

.PHONY: all clean install test dump
