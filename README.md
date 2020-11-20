# semgrep-grammars

[![CircleCI](https://circleci.com/gh/returntocorp/semgrep-grammars.svg?style=svg)](https://circleci.com/gh/returntocorp/semgrep-grammars)

Extensions of public tree-sitter grammars used by
[semgrep](https://github.com/returntocorp/semgrep).

## Setup Instructions
1. Once you have cloned semgrep-grammar, run `make setup` to install the tree-sitter command into node_modules/.bin. Check that the `tree-sitter-*` packages are installed under `node-modules`.
2. Run `make build`. This will build necessary files later processed by ocaml-tree-sitter.

## Language-porting Instructions
1. Git clone the semgrep-grammars repo. Follow the instructions
    you may find, and ensure the `tree-sitter-*` packages end up installed
    under `node_modules`.
 2. Find the GitHub project for the tree-sitter grammar,
    typically named `tree-sitter-X` where `X` is the language name.
 3. Fork the Github project `tree-sitter-X` into the returntocorp organization.
    This lets programmers improve the original grammar in the forked repository
    and later push changes upstream to the original tree-sitter repository.
 4. Add `tree-sitter-X`
    [as a submodule](https://github.com/returntocorp/semgrep-grammars/tree/master/src).
 5. Create `src/semgrep-X`. Then create symlinks to `../Makefile.common` and `../prep.common`
    in `src/semgrep-X` with the commands:
    `ln -s ../Makefile.common Makefile`
    `ln -s ../prep.common prep`
 6. Create `src/semgrep-X/grammar.js`. As a first step, create a boilerplate to extending the
    grammar. You do not need to add semgrep pattern constructs just yet.
    Later, you will want to add on to `src/semgrep-X/grammar.js` such that it extends the original
    grammar with the semgrep pattern constructs (`...`, `$X`).
 7. Add `tree-sitter-X` to `TREE_SITTER_PACKAGES` and `semgrep-X` to
    SEMGREP_PACKAGES in `src/Makefile`.
 8. Run `make` to generate tree-sitter files.
 9. Create directory `test/corpus` inside of `src/semgrep-X` and add
    language files to the corpus. You can also just take the tree-sitter test
    files by symlinking them:
    `ln -s ../../../tree-sitter-X/<path-to-test-corpus> inherited`
 10. Write tests for the new syntax if you have specific tests you want to check.
    Run `make test` from your
    `semgrep-X` folder until things work. You will know that tests have run
    and passed when you see green check marks next to test names.
 11. Create a symlink for your language under
    [`lang/`](https://github.com/returntocorp/semgrep-grammars/tree/master/lang)
    with the command:
    `ln -s ../src/semgrep-X X`
    in the `lang` folder.
 12. Try running `make && make test` to make sure things are still functioning.
