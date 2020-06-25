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
4. Build with `make`.
5. Install with `make install`.
6. Test with `make test`.

## Documentation

* [Contributor documentation](doc/overview.md)
* No user documentation exists at this time.

## License

ocaml-tree-sitter is free software with contributors from multiple
organizations. The project is driven by R2C.

- OCaml code developed specifically for this project is
  distributed under the terms of the [GNU GPL v3](LICENSE).
- The OCaml bindings to tree-sitter's C API were created by Bryan
  Phelps as part of the reason-tree-sitter project.
- The tree-sitter grammars for major programming languages were imported
  from their respective projects, and we try to keep them in sync.
  Each comes with its own license.
