(*
   Locations in a source file.
*)

type pos = Tree_sitter_output_t.position = {
  row : int;
  column : int;
}
[@@deriving show {with_path = false}]

type t = {
  start: pos;
  end_: pos;
}
[@@deriving show {with_path = false}]
