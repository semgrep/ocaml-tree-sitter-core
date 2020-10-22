(*
   Representation of an input file.
*)

type info = {
  name: string; (* path to the file or to an informal descriptor
                   such as '<stdin>' *)
  path: string option; (* path to the file, if applicable *)
}

type t = private {
  info: info;
  lines: string array;
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

(*
   Return the substring corresponding to the specified region.
   It may or may not coincide with the boundaries of a token.
*)
val get_region : t -> Loc.pos -> Loc.pos -> string

(*
   Get the specified line from the line array.
   The first line (row) is numbered 0.
   If the requested line is out of range, the empty string is returned.
*)
val safe_get_row : t -> int -> string
