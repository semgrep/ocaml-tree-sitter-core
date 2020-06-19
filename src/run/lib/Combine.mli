(*
   Generic functions for combining parsers.
*)

open Tree_sitter_bindings.Tree_sitter_output_t

(*
   A reader looks into a sequence of symbols (nodes) for a certain pattern,
   resulting in one of two outcomes:
   - the sequence doesn't match (None)
   - the sequence matches, consuming a number of nodes to construct a value
     (Some value), returning the remaining sequence.
*)
type 'a reader = node list -> ('a * node list) option

(*
   The type of a reader that can't be followed by more parsing.
   This is the generic type for parse_children_XXX functions in generated
   code.
*)
type 'a full_seq_reader = node list -> 'a option

(*
   A type alias for a reader capable of backtracking.

   By providing the function to read the rest of the input (tail),
   the reader can try different ways to parse the head until it finds one
   that allows matching the tail as well.

   For example, parse_optional (provided by this module) has such capability.

     parse_optional parse_int parse_tail : (int, int option, _) reader

   will try to take an int from the input. Even if successfully obtaining
   'Some 42', it must call parse_tail successfully on the remaining input.
   If it fails, it rejects the int, using 'None' and then calls parse_tail
   on the original input sequence, which may succeed.
*)
type ('head_elt, 'head, 'tail) seq_reader =
  'head_elt reader -> 'tail reader -> ('head * 'tail) reader

(* [parse_rule name parse_children] returns a parser that expects a node
   with the given name and parses its children using [parse_children].
   It is illegal for the [parse_children] function to not consume all
   the children.
*)
val parse_rule : string -> (node list -> 'a option) -> 'a reader

(* Always fail/succeed without consuming the input. *)
val parse_fail : 'a reader
val parse_success : unit reader

(* Create a reader of a single input node. *)
val parse_node : (node -> 'a option) -> 'a reader

(* Trace a function so as print:
   - when it gets called
   - a peek into its input
   - when it returns
   - the return status (success/failure)
*)
val trace : string -> (node list -> 'a option) -> (node list -> 'a option)

(* More specific version of 'trace', which shows the remaining input
   upon returning.
*)
val trace_reader : string -> 'a reader -> 'a reader

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
           (* : ('a, 'a, 'tail) seq_reader *)

(* Force a match to extend to the end of the input sequence.

   This is intended to be used in generated code as:

     let parse_children =
       parse_full_seq parse_inline_thing

   It turns a seq_reader into a full_seq_reader:

     ('a, 'a, unit) seq_reader -> 'a full_seq_reader
*)
val parse_full_seq :
  (unit reader -> ('head * unit) reader) ->
  (node list -> 'head option)

(* Match at the end of input. *)
val parse_end : unit reader

(* Read zero or more elements of the same kind, then the rest of the
   sequence. Prioritizes longest match first. *)
val parse_repeat : 'a reader -> 'tail reader -> ('a list * 'tail) reader
              (* : ('a, 'a list, 'tail) seq_reader *)

(* Try to read one or more elements of the same kind, then the rest of the
   sequence. Prioritizes longest match first. *)
val parse_repeat1 : 'a reader -> 'tail reader -> ('a list * 'tail) reader
               (* : ('a, 'a list, 'tail) seq_reader *)

(* Read one or zero element. Prioritizes longest match first. *)
val parse_optional : 'a reader -> 'tail reader -> ('a option * 'tail) reader
                (* : ('a, 'a option, 'tail) seq_reader *)

(* Convert the result of a reader. *)
val map : ('a -> 'b) -> 'a reader -> 'b reader
val map_fst : ('a -> 'b) -> ('a * 'c) reader -> ('b * 'c) reader

(* Memoization functions designed to cache the result of matching a subtree. *)
module Memoize : sig
  type 'a t
  val create : unit -> 'a t
  val apply : 'a t -> 'a reader -> 'a reader
end

(* Read a single rule, typically the root of the json input.

   Additionally, remove all nodes whose 'type' field is mentioned in the
   'extras' blacklist. This is meant to remove comments and such, which
   may occur anywhere without matching a rule.
*)
val parse_root : extras:string list -> 'a reader -> node -> 'a option
