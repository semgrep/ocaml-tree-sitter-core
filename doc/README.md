ocaml-tree-sitter-core documentation
==

Overview:

* [Overview of ocaml-tree-sitter](overview.md)

Setup:

* [How to set up Node.js and npm](node-setup.md)
* [Related git repositories](related-repos.md)

Internals:

* [How to add support for a new language](adding-a-language.md)
* [Generating good CST type definitions](cst.md)
* [Code generation pipeline](code-generation-pipeline.md)
* [Interpreting the output of tree-sitter](parsing.md)
* [How to upgrade the grammar for a language](updating-a-grammar.md)
* [Parsing stats precision](parsing-stats-precision.md)

See also:
* [ocaml-tree-sitter-lang/doc](https://github.com/returntocorp/ocaml-tree-sitter-semgrep/tree/main/doc):
  Community repository for managing and publishing OCaml libraries for
  various programming languages.

* [ocaml-tree-sitter-semgrep/doc](https://github.com/returntocorp/ocaml-tree-sitter-languages/tree/main/doc):
  Semgrep-specific repository for managing and publishing OCaml
  libraries for various programming languages. Each language is
  extended with Semgrep pattern constructs such as `...`, `$METAVAR`,
  etc.
