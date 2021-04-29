(*
   Convert precedence values that can be either an int or a string into
   OCaml variants.

   This is the standard interface expected by Tree_sitter.atd.
*)

val normalize : Yojson.Safe.t -> Yojson.Safe.t
val restore : Yojson.Safe.t -> Yojson.Safe.t
