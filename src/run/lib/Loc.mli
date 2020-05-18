(*
   A location in a source file, expressed as pair of positions.
*)

type pos = Tree_sitter_output_t.position = {
  row : int;
  column : int;
}
[@@deriving show {with_path = false}]

(* TODO: include filename as a field? *)
type t = {
  start: pos;
  end_: pos;
}
[@@deriving show {with_path = false}]
