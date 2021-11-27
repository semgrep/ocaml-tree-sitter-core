ocaml-tree-sitter-core
==

[![CircleCI](https://circleci.com/gh/returntocorp/ocaml-tree-sitter-core.svg?style=svg)](https://circleci.com/gh/returntocorp/ocaml-tree-sitter-core)

Generate OCaml parsers based on
[tree-sitter](https://tree-sitter.github.io/tree-sitter/) grammars.
This project was originally intended
for [semgrep](https://github.com/returntocorp/semgrep).
This repository contains the code for generating code for tree-sitter
grammars but does not contain grammars for specific languages other
than tests.

The ocaml-tree-sitter repositories are:
* **ocaml-tree-sitter-core**: this repo; provides the code generator that
  takes a tree-sitter grammar and produces an OCaml library from it.
* [ocaml-tree-sitter-languages](https://github.com/returntocorp/ocaml-tree-sitter-languages): community repository that has scripts
  for building and publishing OCaml libraries for parsing a variety of
  programming languages.
* [ocaml-tree-sitter-semgrep](https://github.com/returntocorp/ocaml-tree-sitter-semgrep): same as ocaml-tree-sitter-languages but
  extends each language with constructs specific to
  [semgrep](https://github.com/returntocorp/semgrep) patterns.

Installation
--

Installing `ocaml-tree-sitter` alone isn't of great use at the
moment. It is useful as part of the flow for generating OCaml parsers
from tree-sitter grammars, which is done from the `lang/` folder
in [ocaml-tree-sitter-semgrep](https://github.com/returntocorp/ocaml-tree-sitter-semgrep).
See the **Contributing** instructions below.

Contributing
--

Before you get started, make sure you're ok with signing the
[CLA](https://cla-assistant.io/returntocorp/ocaml-tree-sitter-core)
which will be needed before we accept your pull request. The goal is
only to allow future relicensing without having to track down any past
contributor, if such need were to arise. Note that the current license is
GPLv3 and any contribution made today will remain available under that
license no matter what.

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

For building or rebuilding everything after big changes, use these scripts:
```
$ ./scripts/install-tree-sitter-cli --bindir DST
$ ./scripts/rebuild-everything  # needs root access to install libtree-sitter
```

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
