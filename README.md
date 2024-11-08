ocaml-tree-sitter-core
==

[![CircleCI](https://circleci.com/gh/semgrep/ocaml-tree-sitter-core.svg?style=svg)](https://circleci.com/gh/semgrep/ocaml-tree-sitter-core)

Generate OCaml parsers based on
[tree-sitter](https://tree-sitter.github.io/tree-sitter/) grammars.
This project was originally intended
for [semgrep](https://github.com/semgrep/semgrep).
This repository contains the code for generating code for tree-sitter
grammars but does not contain grammars for specific languages other
than tests.

The ocaml-tree-sitter repositories are:
* **ocaml-tree-sitter-core**: this repo; provides the code generator that
  takes a tree-sitter grammar and produces an OCaml library from it.
* [ocaml-tree-sitter-languages](https://github.com/semgrep/ocaml-tree-sitter-languages): community repository that has scripts
  for building and publishing OCaml libraries for parsing a variety of
  programming languages.
* [ocaml-tree-sitter-semgrep](https://github.com/semgrep/ocaml-tree-sitter-semgrep): same as ocaml-tree-sitter-languages but
  extends each language with constructs specific to
  [semgrep](https://github.com/semgrep/semgrep) patterns.

Installation
--

Installing `ocaml-tree-sitter` alone isn't of great use at the
moment. It is useful as part of the flow for generating OCaml parsers
from tree-sitter grammars, which is done from the `lang/` folder
in [ocaml-tree-sitter-semgrep](https://github.com/semgrep/ocaml-tree-sitter-semgrep).
See the **Contributing** instructions below.

Contributing
--

Before you get started, make sure you're ok with signing the
[CLA](https://cla-assistant.io/semgrep/ocaml-tree-sitter-core)
which will be needed before we accept your pull request. The goal is
only to allow future relicensing without having to track down any past
contributor, if such need were to arise. Note that the current license is
LGPL and any contribution made today will remain available under that
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
$ make distclean
$ ./configure
$ make setup
$ ./scripts/rebuild-everything  # needs root access to install libtree-sitter
```

### tree-sitter version

The default tree-sitter version to use is in the
`tree-sitter-version.default` file.

Under the default configuration used for local development purposes,
the version being actually used is stored in the file
`tree-sitter-version`. This can be changed by invoking
`./scripts/switch-tree-sitter-version` before `make setup`.
We made this available to facilitate the transition from tree-sitter 0.20.6 to
0.22.6 in ocaml-tree-sitter-semgrep where the integration of some
grammars needs to be updated. The latest version of these grammars are
compatible with 0.22.6 but their OCaml integration in Semgrep needs work.

Documentation
--

We have limited [documentation](doc) which is mostly targeted at
early contributors. It's growing organically based on demand, so don't
hesitate to [file an issue](https://github.com/semgrep/ocaml-tree-sitter-core/issues)
explaining what you're trying to do.

License
--

ocaml-tree-sitter is free software with contributors from multiple
organizations. The project is driven by [Semgrep](https://github.com/semgrep).

- OCaml code developed specifically for this project is
  distributed under the terms of the [GNU LGPL 2.1](LICENSE).
- The OCaml bindings to tree-sitter's C API were created by Bryan
  Phelps as part of the reason-tree-sitter project.
- The tree-sitter grammars for major programming languages are
  external projects. Each comes with its own license.
