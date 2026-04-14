(*
   Various helper functions called directly by the generated code.
*)

val get_loc : Tree_sitter_bindings.Tree_sitter_output_t.node -> Loc.t

(** Get a node's children list, defaulting to [] for leaves. *)
val children :
  Tree_sitter_bindings.Tree_sitter_output_t.node ->
  Tree_sitter_bindings.Tree_sitter_output_t.node list

(** Extract a token (location + text) from a leaf node. *)
val token :
  Src_file.t ->
  Tree_sitter_bindings.Tree_sitter_output_t.node ->
  Token.t

(** Get the single child, raising if there isn't exactly one. *)
val single :
  Tree_sitter_bindings.Tree_sitter_output_t.node list ->
  Tree_sitter_bindings.Tree_sitter_output_t.node

(** Safe access to the nth element of a list. *)
val nth_opt :
  Tree_sitter_bindings.Tree_sitter_output_t.node list ->
  int ->
  Tree_sitter_bindings.Tree_sitter_output_t.node option

(** Report a matching failure with context. *)
val fail :
  Tree_sitter_bindings.Tree_sitter_output_t.node ->
  string ->
  'a

(** Match a children list against a list of expected kind-patterns.
    Returns the index of the first matching pattern, or -1 if none match. *)
val select :
  Tree_sitter_bindings.Tree_sitter_output_t.node list ->
  Tree_sitter_bindings.Tree_sitter_output_t.node_kind list list ->
  int * Tree_sitter_bindings.Tree_sitter_output_t.node list

val extract_errors :
  Src_file.t ->
  Tree_sitter_bindings.Tree_sitter_output_t.node ->
  Tree_sitter_error.t list

val remove_extras :
  keep_node:(Tree_sitter_bindings.Tree_sitter_output_t.node -> bool) ->
  Tree_sitter_bindings.Tree_sitter_output_t.node ->
  Tree_sitter_bindings.Tree_sitter_output_t.node

val translate :
  extras:string list ->
  translate_root:(Tree_sitter_bindings.Tree_sitter_output_t.node -> 'a) ->
  translate_extra:(Tree_sitter_bindings.Tree_sitter_output_t.node ->
                   'b option) ->
  Tree_sitter_bindings.Tree_sitter_output_t.node ->
  'a * 'b list
