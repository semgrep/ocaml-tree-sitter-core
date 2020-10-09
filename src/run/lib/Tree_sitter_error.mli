(*
   Error message formatting.
*)

type kind =
  | Internal (* a bug *)
  | External (* malformed input or bug, but we don't know *)

type t = {
  kind: kind;
  msg: string;

  (*
     Provides the path to the source file if applicable.
  *)
  file: Src_file.info;

  (*
     Beginning and end of the error node reported by tree-sitter.
     The end position is inclusive, i.e. it's the position of the last
     character of the selected region.
  *)
  start_pos: Tree_sitter_bindings.Tree_sitter_output_t.position;
  end_pos: Tree_sitter_bindings.Tree_sitter_output_t.position;

  (*
     The region of the code (tree-sitter error node) reported as an error.
     This could almost be extracted from the snippet field, but here we
     guarantee no ellipsis.
  *)
  substring: string;

  (*
     A structured snippet of code extracted from the source input,
     including lines of context, regions to be highlighted, and ellipses
     if a string is too long. See Snippet.format for rendering
     to a terminal or as plain text.
  *)
  snippet: Snippet.t;
}

(* Fatal parsing error. *)
exception Error of t

(*
   Create an error object from a node considered to be the cause of
   a parsing error.
*)
val create :
  kind ->
  Src_file.t ->
  Tree_sitter_bindings.Tree_sitter_output_t.node ->
  string -> t

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
