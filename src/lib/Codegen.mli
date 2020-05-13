(*
   Convert a grammar to OCaml type definitions.
*)

(*
   Generate files AST_$lang.ml and Parse_$lang.ml
*)
val ocaml : ?out_dir:string ->  ?lang:string -> AST_grammar.t -> unit
