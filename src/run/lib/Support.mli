(*
   Various functions used by generated parsers.
*)

open Tree_sitter_output_t


(*
   A reader looks into a sequence of symbols (nodes) for a certain pattern,
   resulting in one of two outcomes:
   - the sequence doesn't match (None), returning the original sequence
   - the sequence matches, consuming a number of nodes to construct a value
     (Some value), returning the remaining sequence.

   The return type is ('a option * node list) rather than
   ('a * node list) option to allow chaining using parse_seq (monadic bind
   operator >>=).
*)
type 'a wrapped_result = 'a option * node list
type 'a unwrapped_result = 'a * node list
type 'a reader = node list -> 'a wrapped_result

(* Read zero or more elements of the same kind. Always succeed. *)
val parse_repeat: 'a reader -> 'a list reader

(* Try to read one or more elements of the same kind. *)
val parse_repeat1 : 'a reader -> 'a list reader

(* Try to read one element, trying successive parsers from left to right. *)
val parse_choice: 'a reader list -> 'a reader

(* Combine the result of parsing an element with the result of parsing
   the next element. It is aliased to (>>=) in generated code for clarity.
*)
val parse_seq :
  'a wrapped_result ->
  ('a unwrapped_result -> 'b wrapped_result) ->
  'b wrapped_result
