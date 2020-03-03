all: grammar.json ex1.json ast.re

TOP=../..

# you need 'make' from $(TOP)
GEN=$(TOP)/_build/default/bin/main_codegen.exe
# you need 'npm install tree-sitter-cli' from $(TOP)
CLI=$(TOP)/../node_modules/.bin/tree-sitter

grammar.json: grammar.js
	$(CLI) generate
	cp -f src/grammar.json .

ex1.json: ex1.txt grammar.json
	npm init -y
	npm install
	./dumper.js ex1.txt > ex1.json

ast.re: grammar.json
	$(GEN) -codegen_types grammar.json > ast.re


clean:
	rm -f *.gyp index.js
	rm -rf src/ build/
	rm -f package-lock.json package.json

distclean:
	rm -f grammar.json ex1.json ast.re
