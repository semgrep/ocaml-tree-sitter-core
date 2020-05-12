(*
   Sort rules topologically so as to print out type definitions in the
   order of their dependencies.

   This uses the Containers library.
   https://c-cube.github.io/ocaml-containers/2.5/containers/CCGraph/index.html

   This improves the clarity of the generated code.
   (there are also compile-time performance benefits when generating
   OCaml functions from type definitions)
*)

(* Sort rules topologically, such that a rule may only reference earlier
   rules. A single rule may reference itself but multiple rules may not
   reference each other. In such case, the result is None.
*)
val sort : AST_grammar.rule list -> AST_grammar.rule list option
