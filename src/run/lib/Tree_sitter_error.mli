(*
   Error message formatting.
*)

type kind =
  | Internal (* a bug *)
  | External (* malformed input or bug, but we don't know *)

type t = {
  kind: kind;
  msg: string;
  file: Src_file.info;
  start_pos: Tree_sitter_bindings.Tree_sitter_output_t.position;
  end_pos: Tree_sitter_bindings.Tree_sitter_output_t.position;
  snippet: Snippet.t;
}

(* Fatal parsing error. *)
exception Error of t

(*
   Fail, raising an External_error exception.
   The string argument is an arbitrary message to be printed as part of
   an error message.
*)
val external_error :
  Src_file.t ->
  Tree_sitter_bindings.Tree_sitter_output_t.node ->
  string -> 'a

(*
   Fail, raising an Internal_error exception.
   The string argument is an arbitrary message to be printed as part of
   an error message.
*)
val internal_error :
  Src_file.t ->
  Tree_sitter_bindings.Tree_sitter_output_t.node ->
  string -> 'a

(*
   Format an error message. Highlight the error for an ANSI terminal iff
   'color' is true. 'color' is false by default.
*)
val to_string : ?color:bool -> t -> string
