(*
   A token, i.e. a string with its location in the file where it comes from.
*)

type t = Loc.t * string
[@@deriving show {with_path = false}]
