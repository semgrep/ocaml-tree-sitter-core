(*
   Simple utilities to work on the types defined in Tree_sitter_output.atd.
*)

open Printf
open Ocaml_tree_sitter_bindings.Tree_sitter_output_t

(* Take an error message and prepend the location information,
   in a human-readable and possibly computer-readable format (TODO check with
   emacs etc.)

   TODO: include file name in messages.
*)
let prepend_msg node msg =
  let start = node.start_pos in
  let end_ = node.end_pos in
  if start.row = end_.row then
    sprintf "Line %i, characters %i-%i:\n%s"
      start.row start.column end_.column msg
  else
    sprintf "Line %i, character %i to line %i, character %i:\n%s"
      start.row start.column end_.row end_.column msg

let fail node msg =
  let msg =
    sprintf "tree-sitter output node of type %S could not be parsed:\n%s"
      node.type_ msg
  in
  let msg = prepend_msg node msg in
  failwith msg
