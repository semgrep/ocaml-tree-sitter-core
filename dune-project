(lang dune 3.20)
(using directory-targets 0.1)

(name tree-sitter)
(generate_opam_files)
(source
  (github semgrep/ocaml-tree-sitter-core))

(package
  (name tree-sitter)
  (synopsis "Code generator for parsing the output of tree-sitter parsers")
  (description
    "Ocaml-tree-sitter translates a tree-sitter json grammar to OCaml code for
    recovering a full CST from the output for a tree-sitter parser.")
  (maintainers
    "Martin Jambon <martin@semgrep.com>")
  (authors
     "Semgrep, Inc.")
  (license LGPL-2.1-only)
  (homepage https://github.com/semgrep/ocaml-tree-sitter-core)
  (bug_reports https://github.com/semgrep/ocaml-tree-sitter-core/issues)
  (depends
     alcotest
     ANSITerminal
     atdgen
     (cmdliner  (< 2.0.0))
     conf-pkg-config
     dune
     (dune-configurator (>= 3.10.0))
     base
     ocaml
     ppx_deriving
     sexplib
     (tsort (>= 2.0))))
