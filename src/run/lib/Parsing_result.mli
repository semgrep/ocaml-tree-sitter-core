(*
   A semi-generic type used to hold the results of parsing a file.
*)

type stat = {
  total_line_count: int;
  error_line_count: int; (* number of lines affected by one or more errors *)
  error_count: int;
}

type 'a t = {
  program: 'a option;
  errors: Tree_sitter_error.t list;
  stat: stat;
}

val create : Src_file.t -> 'a option -> Tree_sitter_error.t list -> 'a t

val export_stat : out_file:string -> stat -> unit
