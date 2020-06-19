(*
   OCaml-friendly representation of parse trees produced by tree-sitter.
*)

(* Convert the C API tree to a convenient OCaml tree. *)
val of_ts_tree : Tree_sitter_API.ts_tree -> Tree_sitter_output_t.node
