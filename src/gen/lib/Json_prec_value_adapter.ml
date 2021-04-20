(*
   Convert precedence values that can be either an int or a string into
   OCaml variants.

   This is used in Tree_sitter.atd.
*)

type json = Yojson.Safe.t

let normalize (json : json) : json =
  match json with
  | `Int i -> `List [`String "Num_prec"; `Int i]
  | `String s -> `List [`String "Named_prec"; `String s]
  | malformed -> malformed

let restore (json : json) : json =
  match json with
  | `List [`String "Num_prec"; `Int i] -> `Int i
  | `List [`String "Named_prec"; `String s] -> `String s
  | malformed -> malformed
