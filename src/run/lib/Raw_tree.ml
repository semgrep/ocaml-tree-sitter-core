(*
   A generic tree type meant to accommodate all tree types derived
   from tree-sitter grammars.
*)

type 'a t =
  | Token of Token.t
  | List of 'a t list
  | Tuple of 'a t list
  | Case of string * 'a t
  | Option of 'a t option
  | Any of 'a
