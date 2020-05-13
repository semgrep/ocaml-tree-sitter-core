.PHONY: build
build:
	dune build
	test -e bin || ln -s _build/install/default/bin .

.PHONY: clean
clean:
	# remove everything that's git-ignored
	git clean -dfX

.PHONY: test
test: build
	./scripts/run-test

.PHONY: install
install:
	dune install
