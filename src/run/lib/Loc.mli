(*
   A location in a source file, expressed as pair of positions.
*)

type pos = Ocaml_tree_sitter_bindings.Tree_sitter_output_t.position = {
  row : int;
  column : int;
}

(* TODO: include filename as a field? *)
type t = {
  start: pos;
  end_: pos;
}
