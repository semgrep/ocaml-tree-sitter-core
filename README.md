# ocaml-tree-sitter

[![CircleCI](https://circleci.com/gh/returntocorp/ocaml-tree-sitter.svg?style=svg)](https://circleci.com/gh/returntocorp/ocaml-tree-sitter)

Generate OCaml parsers based on
[tree-sitter](https://tree-sitter.github.io/tree-sitter/) grammars.

## Installation

ocaml-tree-sitter is under initial development and is not ready to be
installed or used by a wide audience.

## Contributing

Development setup:

1. Install [opam](https://opam.ocaml.org/doc/Install.html).
2. Install [ocaml dev tools for your favorite
   editor](https://github.com/janestreet/install-ocaml):
   typically `opam install merlin` + some plugin for your editor.
3. Install `pre-commit` with `pip3 install pre-commit` and run
   `pre-commit install` to set up the pre-commit hook.
   This will re-indent code in a consistent fashion each time you call
   `git commit`.

For building or rebuilding everything after big changes, use this script:
```
./scripts/rebuild-everything
```

For working with the OCaml source code for the ocaml-tree-sitter code
generator, the normal development commands are:
1. `make`
2. `make install` - necessary for generating parser code in the steps below.
3. `make test`

For updating a tree-sitter grammar, the typical process is:
1. Edit the `tree-sitter-X` project on GitHub corresponding to
   the target language X.
2. Go to `lang/semgrep-grammars/src/tree-sitter-X` and pull the git
   commit you want to test.
3. Optionally update the semgrep syntax extensions in
   `lang/semgrep-grammars/src/semgrep-X`.
4. Run `make -C lang` and `make -C lang test` to build and test the
   extended grammar for language X.
5. Publish the generated code with `make -C lang release`.

### Contributing on MacOS

* Note that you must have Xcode and CLT installed for Mac to run make setup.
* If you are having trouble with node setup, reference [node page](https://github.com/returntocorp/ocaml-tree-sitter/blob/master/doc/node-setup.md).
* You must also have bash version 4.0 or higher. To make this your default bash:
   1. Run `brew install bash` or `brew upgrade bash`
   2. Go to `/etc/shells` and add `usr/local/bin/bash`
   3. Run `chsh -s /usr/local/bin/bash`
   4. Close your shell and reopen. To check your bash version, run `bash --version`.

### Testing Parsing for a Specific Language

1. Go to `ocaml-tree-sitter/lang/semgrep-grammars/src`.
2. Build with `make`.
3. Go to `ocaml-tree-sitter/lang/<language name>`.
4. Build with `make`.

## Documentation

We have limited [documentation](doc) which is mostly targeted at
early contributors. It's growing organically based on demand, so don't
hesitate to [file an issue](https://github.com/returntocorp/ocaml-tree-sitter/issues)
explaining what you're trying to do.

## License

ocaml-tree-sitter is free software with contributors from multiple
organizations. The project is driven by r2c.

- OCaml code developed specifically for this project is
  distributed under the terms of the [GNU GPL v3](LICENSE).
- The OCaml bindings to tree-sitter's C API were created by Bryan
  Phelps as part of the reason-tree-sitter project.
- The tree-sitter grammars for major programming languages were imported
  from their respective projects, and we try to keep them in sync.
  Each comes with its own license.
