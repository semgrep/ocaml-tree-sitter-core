(*
   Representation of an input file.
*)

type t

type info = {
  name: string; (* path to the file or to an informal descriptor
                   such as '<stdin>' *)
  path: string option; (* path to the file, if applicable *)
}

val info : t -> info

(*
   Load an input file. It gets resolved into lines and columns.
*)
val load_file : string -> t

(*
   Load source code from a string. The optional 'src_file' is for
   pointing to the source file in error messages.
   If 'src_file' is unspecified, the name of the file in error messages
   can be set with 'src_name' without having to be a valid path.
   The default for 'src_name' is "<source>".
*)
val load_string : ?src_name:string -> ?src_file:string -> string -> t

val get_token : t -> Loc.pos -> Loc.pos -> string
