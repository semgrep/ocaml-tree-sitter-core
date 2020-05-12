(*
   Change the name of identifiers that would make unsuitable Reason
   identifiers. This tracks all identifiers to avoid conflicts.
*)

(* Registry of translated identifiers. *)
type t

(* All English keywords that can't be used as type names in Reason. *)
val reason_keywords : string list

(*
   Initialize a translation registry, using the specified list of reserved
   keywords, to which an underscore will be appended.
   The default list is reason_keywords.
*)
val create : ?reserved:string list -> unit -> t

(* Translate an identifier to a valid Reason identifier, ensuring that
   the new identifier is as close as possible to the original and that the
   resulting identifier is not already in use by something else.
*)
val translate : t -> string -> string
