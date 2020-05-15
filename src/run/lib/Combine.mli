(*
   Generic functions for combining parsers.
*)

open Tree_sitter_output_t

(*
   A reader looks into a sequence of symbols (nodes) for a certain pattern,
   resulting in one of two outcomes:
   - the sequence doesn't match (None)
   - the sequence matches, consuming a number of nodes to construct a value
     (Some value), returning the remaining sequence.
*)
type 'a reader = node list -> ('a * node list) option

(* A success reader is a reader that always succeeds so we don't need to
   wrap it in an option type. *)
type 'a success_reader = node list -> ('a * node list)

(* Create a reader of a single input node. *)
val parse_node: (node -> 'a option) -> 'a reader

(* Read zero or more elements of the same kind. Always succeed. *)
val parse_repeat: 'a reader -> 'a list success_reader

(* Try to read one or more elements of the same kind. *)
val parse_repeat1 : 'a reader -> 'a list reader
