(*
   Change the name of identifiers that would make unsuitable OCaml
   identifiers. This tracks all identifiers to avoid conflicts.
*)

(* Registry of translated identifiers. *)
type t

(* Lowercase identifiers that are keywords in OCaml. *)
val ocaml_keywords : string list

(* Lowercase identifiers that are built-in type names in OCaml. *)
val ocaml_builtin_types : string list

(* Union of ocaml_keywords and ocaml_builtin_types *)
val ocaml_reserved : string list

(*
   Initialize a translation registry, using the specified list of reserved
   keywords, to which an underscore will be appended.
   The default list is ocaml_reserved.
*)
val create : ?reserved:string list -> unit -> t

(* Translate an identifier to a valid OCaml/Reason identifier, ensuring that
   the new identifier is as close as possible to the original and that the
   resulting identifier is not already in use by something else.
*)
val translate : t -> string -> string
