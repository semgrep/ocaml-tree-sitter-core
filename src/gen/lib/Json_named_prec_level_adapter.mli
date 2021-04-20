(*
   Fix up json representing a 'named_prec_level' in Tree_sitter.atd.

   This is the standard interface expected by Tree_sitter.atd.
*)

val normalize : Yojson.Safe.t -> Yojson.Safe.t
val restore : Yojson.Safe.t -> Yojson.Safe.t
