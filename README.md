# ocaml-tree-sitter

[![CircleCI](https://circleci.com/gh/returntocorp/ocaml-tree-sitter.svg?style=svg)](https://circleci.com/gh/returntocorp/ocaml-tree-sitter)

Generate OCaml parsers based on
[tree-sitter](https://tree-sitter.github.io/tree-sitter/) grammars.

## Installation

ocaml-tree-sitter is under initial development and is not ready to be
installed or used by a wide audience.

## Contributing

1. Install [opam](https://opam.ocaml.org/doc/Install.html).
2. Install [ocaml dev tools for your favorite
   editor](https://github.com/janestreet/install-ocaml):
   typically `opam install merlin` + some plugin for your editor.
3. Install the project's dependencies,
   possibly with `opam install --deps-only ocaml-tree-sitter.opam`.
4. Install dependencies and tree-sitter-cli with `make setup`.
5. Build with `make`.
6. Install with `make install`.
7. Test with `make test`.

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
