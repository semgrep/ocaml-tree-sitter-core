(*
   Locations in a source file.
*)

type pos = Tree_sitter_bindings.Tree_sitter_output_t.position = {
  row : int;
  column : int;
}

type t = {
  start: pos;
  end_: pos;
}

(* compact representation to avoid cluttering dumped trees *)
let sexp_of_pos (x : pos) =
  Sexplib.Sexp.Atom (Printf.sprintf "%d:%d" x.row x.column)

(* compact representation to avoid cluttering dumped trees *)
let sexp_of_t ({start; end_} : t) =
  Sexplib.Sexp.Atom (Printf.sprintf "%d:%d-%d:%d"
                       start.row start.column
                       end_.row end_.column)
