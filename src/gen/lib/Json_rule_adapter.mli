(*
   Convert between tree-sitter's representation of variants
   e.g. {"type": "SYMBOL", "name": "foo"} and atd's convention
   e.g. ["SYMBOL", "foo"].

   This is used in Tree_sitter.atd.
*)

type json = Yojson.Safe.t
val normalize : json -> json
val restore : json -> json
