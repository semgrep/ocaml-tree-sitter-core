ocaml-tree-sitter
==

[![CircleCI](https://circleci.com/gh/returntocorp/ocaml-tree-sitter.svg?style=svg)](https://circleci.com/gh/returntocorp/ocaml-tree-sitter)

Generate OCaml parsers based on
[tree-sitter](https://tree-sitter.github.io/tree-sitter/) grammars,
for [semgrep](https://github.com/returntocorp/semgrep).

Installation
--

Installing `ocaml-tree-sitter` alone isn't of great use at the
moment. It is useful as part of the flow for generating OCaml parsers
from tree-sitter grammars, which is done from the `lang/` folder.
See the **Contributing** instructions below.

Contributing
--

### Development setup

1. Install [opam](https://opam.ocaml.org/doc/Install.html).
2. Install [ocaml dev tools for your favorite
   editor](https://github.com/janestreet/install-ocaml):
   typically `opam install merlin` + some plugin for your editor.
3. Install `pre-commit` with `pip3 install pre-commit` and run
   `pre-commit install` to set up the pre-commit hook.
   This will re-indent code in a consistent fashion each time you call
   `git commit`.
4. Check out the [extra instructions for MacOS](doc/macos.md).

For building or rebuilding everything after big changes, use this script:
```
./scripts/rebuild-everything  # needs root access to install libtree-sitter
```

### Testing a language

Say you want to build and test support for kotlin, you would run this:

```
$ cd lang
$ ./test-lang kotlin
```

For details, see [How to upgrade the grammar for a
language](doc/updating-a-grammar.md).

### Adding a new language

See [How to add support for a new language](doc/adding-a-language.md).

Documentation
--

We have limited [documentation](doc) which is mostly targeted at
early contributors. It's growing organically based on demand, so don't
hesitate to [file an issue](https://github.com/returntocorp/ocaml-tree-sitter/issues)
explaining what you're trying to do.

License
--

ocaml-tree-sitter is free software with contributors from multiple
organizations. The project is driven by [r2c](https://github.com/returntocorp).

- OCaml code developed specifically for this project is
  distributed under the terms of the [GNU GPL v3](LICENSE).
- The OCaml bindings to tree-sitter's C API were created by Bryan
  Phelps as part of the reason-tree-sitter project.
- The tree-sitter grammars for major programming languages are
  external projects. Each comes with its own license.
