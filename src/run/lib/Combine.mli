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

(* Always fail/succeed without consuming the input. *)
val parse_fail : 'a reader
val parse_success : unit reader

(* Create a reader of a single input node. *)
val parse_node : (node -> 'a option) -> 'a reader

(* Read exactly one node. *)
val parse_root : 'a reader -> node -> 'a option

(* Parse the first thing in the sequence then everything else in the
   sequence.

   Usage:

   When requiring the consumption of the full sequence, we use parse_last:

     let parse_case2 nodes =
       let parse_nested =
         let parse_elt = ... in
         let parse_tail =
            let parse_elt = ... in
            let parse_tail =
               let parse_elt = ... in
               Combine.parse_last parse_elt
            in
            Combine.parse_seq parse_elt parse_tail
         in
         Combine.parse_seq parse_elt parse_tail
       in
       match parse_nested nodes with
       | Some ((e1, (e2, e3)), nodes) -> Some (`Case2 (e1, e2, e3), nodes)
       | None -> None

   When we don't need to consume full sequence, we use simply 'parse_elt'
   instead of 'Combine.parse_last parse_elt' above.

   The captured elements are wrapped as '`Case2 (e1, e2, e3)'
   but it could be anything generated from the list ["e1"; "e2"; "e3"].
*)
val parse_seq : 'a reader -> 'tail reader -> ('a * 'tail) reader

(* Match at the end of input. *)
val parse_end : unit reader

(* Parse the last element of a sequence. *)
val parse_last : 'a reader -> 'a reader

(* Read zero or more elements of the same kind, then the rest of the
   sequence. Prioritizes longest match first. *)
val parse_repeat : 'a reader -> 'tail reader -> ('a list * 'tail) reader

(* Try to read one or more elements of the same kind, then the rest of the
   sequence. Prioritizes longest match first. *)
val parse_repeat1 : 'a reader -> 'tail reader -> ('a list * 'tail) reader

(* Convert the result of a reader. *)
val map : ('a -> 'b) -> 'a reader -> 'b reader
val map_fst : ('a -> 'b) -> ('a * 'c) reader -> ('b * 'c) reader

(* Set the id field of all the nodes of an input tree. *)
val assign_unique_ids : node -> node

(* Memoization functions designed to cache the result of matching a subtree. *)
module Memoize : sig
  type 'a t
  val create : unit -> 'a t
  val apply : 'a t -> (node list -> 'a) -> node list -> 'a
end
