PROJECT_ROOT = $(shell git rev-parse --show-toplevel)

# Where tree-sitter-ruby was installed (via npm)
TS_RUBY = $(PROJECT_ROOT)/node_modules/tree-sitter-ruby

# Use the ruby parser installed from tree-sitter-ruby
# because I don't know how to build it. FIXME
#
.PHONY: all
all:
	./run-examples-part1
	mkdir -p src
	ydump $(TS_RUBY)/src/grammar.json > src/grammar.json
	cp $(TS_RUBY)/src/node-types.json src/
	$(PROJECT_ROOT)/scripts/generate-test-part2
