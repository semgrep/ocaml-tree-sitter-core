PROJECT_ROOT = $(shell git rev-parse --show-toplevel)

# Use the ruby parser installed from tree-sitter-ruby
# because I don't know how to build it. FIXME
#
.PHONY: all
all:
	./tree-sitter-ruby.js examples/ex1.rb.src \
	  | ydump > examples/ex1.rb.json
	./tree-sitter-ruby.js examples/ex2.rb.src \
	  | ydump > examples/ex2.rb.json
	./tree-sitter-ruby.js examples/hello.rb.src \
	  | ydump > examples/hello.rb.json
	mkdir -p src
	ydump $(PROJECT_ROOT)/node_modules/tree-sitter-ruby/src/grammar.json \
          > src/grammar.json
	$(PROJECT_ROOT)/scripts/generate-test-part2
