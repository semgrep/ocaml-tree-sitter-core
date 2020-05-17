(*
   Representation of an input file.
*)

type t

(*
   Load an input file. It gets resolved into lines and columns.
*)
val load : string -> t

val get_token : t -> Loc.pos -> Loc.pos -> string
