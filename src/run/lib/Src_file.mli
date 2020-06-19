(*
   Representation of an input file.
*)

type t

(*
   Load an input file. It gets resolved into lines and columns.
*)
val load_file : string -> t

(*
   Load source code from a string. The optional src_file is for
   pointing to the source file in error messages.
*)
val load_string : ?src_file:string -> string -> t

val get_token : t -> Loc.pos -> Loc.pos -> string
