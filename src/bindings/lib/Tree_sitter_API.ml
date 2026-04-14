(*
   OCaml interface to the tree-sitter C functions.

   This is a comprehensive low-level, imperative interface covering the
   tree-sitter C API (v0.22.6): parser, tree, node, tree cursor, query,
   query cursor, language, and lookahead iterator.
*)

(*
   Abstract types wrapping tree-sitter C objects in OCaml custom blocks.
   Each heap-allocated object (parser, tree, query, etc.) has a GC finalizer.
*)
type ts_parser
type ts_tree
type ts_node
type ts_tree_cursor
type ts_query
type ts_query_cursor
type ts_language
type ts_lookahead_iterator

(* Matches Tree_sitter_output_t.position *)
type ts_point = Tree_sitter_output_t.position = {
  row: int;
  column: int;
}

type ts_range = {
  start_point: ts_point;
  end_point: ts_point;
  start_byte: int;
  end_byte: int;
}

type ts_input_edit = {
  start_byte: int;
  old_end_byte: int;
  new_end_byte: int;
  start_point: ts_point;
  old_end_point: ts_point;
  new_end_point: ts_point;
}

type ts_query_capture = {
  capture_node: ts_node;
  capture_index: int;
}

type ts_query_match = {
  match_id: int;
  pattern_index: int;
  captures: ts_query_capture array;
}

type ts_query_predicate_step =
  | Done
  | Capture of int
  | String_literal of int

module Parser = struct
  type t = ts_parser

  external create : unit -> t = "octs_parser_new"
  external delete : t -> unit = "octs_parser_delete"
  external set_language : t -> ts_language -> bool = "octs_parser_set_language"
  external language : t -> ts_language = "octs_parser_language"
  external parse_string : t -> string -> ts_tree = "octs_parser_parse_string"

  external parse :
    t -> ts_tree option -> (int -> int -> int -> string option) ->
      ts_tree option = "octs_parser_parse"

  external reset : t -> unit = "octs_parser_reset"

  external set_timeout_micros :
    t -> int -> unit = "octs_parser_set_timeout_micros"

  external timeout_micros : t -> int = "octs_parser_timeout_micros"

  external set_included_ranges :
    t -> ts_range array -> bool = "octs_parser_set_included_ranges"

  external included_ranges : t -> ts_range array
    = "octs_parser_included_ranges"

  external print_dot_graphs :
    t -> int -> unit = "octs_parser_print_dot_graphs"
end

module Tree = struct
  type t = ts_tree

  external copy : t -> t = "octs_tree_copy"
  external delete : t -> unit = "octs_tree_delete"
  external root_node : t -> ts_node = "octs_tree_root_node"

  external root_node_with_offset :
    t -> int -> ts_point -> ts_node = "octs_tree_root_node_with_offset"

  external language : t -> ts_language = "octs_tree_language"

  external included_ranges :
    t -> ts_range array = "octs_tree_included_ranges"

  external edit : t -> ts_input_edit -> t = "octs_tree_edit"

  external get_changed_ranges :
    t -> t -> ts_range array = "octs_tree_get_changed_ranges"

  external print_dot_graph : t -> int -> unit = "octs_tree_print_dot_graph"
end

module Point = struct
  type t = ts_point
end

module Node = struct
  type t = ts_node

  external type_ : t -> string = "octs_node_type"
  external symbol : t -> int = "octs_node_symbol"
  external language : t -> ts_language = "octs_node_language"
  external grammar_type : t -> string = "octs_node_grammar_type"
  external grammar_symbol : t -> int = "octs_node_grammar_symbol"
  external start_byte : t -> int = "octs_node_start_byte"
  external start_point : t -> ts_point = "octs_node_start_point"
  external end_byte : t -> int = "octs_node_end_byte"
  external end_point : t -> ts_point = "octs_node_end_point"
  external string : t -> string = "octs_node_string"
  external is_null : t -> bool = "octs_node_is_null"
  external is_named : t -> bool = "octs_node_is_named"
  external is_missing : t -> bool = "octs_node_is_missing"
  external is_extra : t -> bool = "octs_node_is_extra"
  external has_changes : t -> bool = "octs_node_has_changes"
  external has_error : t -> bool = "octs_node_has_error"
  external is_error : t -> bool = "octs_node_is_error"
  external parse_state : t -> int = "octs_node_parse_state"
  external next_parse_state : t -> int = "octs_node_next_parse_state"
  external parent : t -> t = "octs_node_parent"

  external child_containing_descendant :
    t -> t -> t = "octs_node_child_containing_descendant"

  external child : t -> int -> t = "octs_node_child"

  external field_name_for_child :
    t -> int -> string option = "octs_node_field_name_for_child"

  external child_count : t -> int = "octs_node_child_count"
  external named_child : t -> int -> t = "octs_node_named_child"
  external named_child_count : t -> int = "octs_node_named_child_count"

  external child_by_field_name :
    t -> string -> t = "octs_node_child_by_field_name"

  external child_by_field_id : t -> int -> t = "octs_node_child_by_field_id"
  external next_sibling : t -> t = "octs_node_next_sibling"
  external prev_sibling : t -> t = "octs_node_prev_sibling"
  external next_named_sibling : t -> t = "octs_node_next_named_sibling"
  external prev_named_sibling : t -> t = "octs_node_prev_named_sibling"

  external first_child_for_byte :
    t -> int -> t = "octs_node_first_child_for_byte"

  external first_named_child_for_byte :
    t -> int -> t = "octs_node_first_named_child_for_byte"

  external descendant_count : t -> int = "octs_node_descendant_count"

  external descendant_for_byte_range :
    t -> int -> int -> t = "octs_node_descendant_for_byte_range"

  external descendant_for_point_range :
    t -> ts_point -> ts_point -> t = "octs_node_descendant_for_point_range"

  external named_descendant_for_byte_range :
    t -> int -> int -> t = "octs_node_named_descendant_for_byte_range"

  external named_descendant_for_point_range :
    t -> ts_point -> ts_point -> t
    = "octs_node_named_descendant_for_point_range"

  external eq : t -> t -> bool = "octs_node_eq"

  (* Custom index helpers, not part of the tree-sitter C API *)
  external index : t -> int = "octs_node_index"
  external named_index : t -> int = "octs_node_named_index"

  external bounded_named_index :
    t -> int = "octs_node_bounded_named_index"
end

module TreeCursor = struct
  type t = ts_tree_cursor

  external create : ts_node -> t = "octs_tree_cursor_new"
  external delete : t -> unit = "octs_tree_cursor_delete"
  external reset : t -> ts_node -> unit = "octs_tree_cursor_reset"
  external reset_to : t -> t -> unit = "octs_tree_cursor_reset_to"
  external current_node : t -> ts_node = "octs_tree_cursor_current_node"

  external current_field_name :
    t -> string option = "octs_tree_cursor_current_field_name"

  external current_field_id :
    t -> int = "octs_tree_cursor_current_field_id"

  external goto_parent : t -> bool = "octs_tree_cursor_goto_parent"

  external goto_next_sibling :
    t -> bool = "octs_tree_cursor_goto_next_sibling"

  external goto_previous_sibling :
    t -> bool = "octs_tree_cursor_goto_previous_sibling"

  external goto_first_child :
    t -> bool = "octs_tree_cursor_goto_first_child"

  external goto_last_child :
    t -> bool = "octs_tree_cursor_goto_last_child"

  external goto_descendant : t -> int -> unit
    = "octs_tree_cursor_goto_descendant"

  external current_descendant_index :
    t -> int = "octs_tree_cursor_current_descendant_index"

  external current_depth :
    t -> int = "octs_tree_cursor_current_depth"

  external goto_first_child_for_byte :
    t -> int -> int = "octs_tree_cursor_goto_first_child_for_byte"

  external goto_first_child_for_point :
    t -> ts_point -> int = "octs_tree_cursor_goto_first_child_for_point"

  external copy : t -> t = "octs_tree_cursor_copy"
end

module Query = struct
  type t = ts_query

  external create : ts_language -> string -> t = "octs_query_new"
  external delete : t -> unit = "octs_query_delete"
  external pattern_count : t -> int = "octs_query_pattern_count"
  external capture_count : t -> int = "octs_query_capture_count"
  external string_count : t -> int = "octs_query_string_count"

  external start_byte_for_pattern :
    t -> int -> int = "octs_query_start_byte_for_pattern"

  external predicates_for_pattern :
    t -> int -> ts_query_predicate_step array
    = "octs_query_predicates_for_pattern"

  external is_pattern_rooted :
    t -> int -> bool = "octs_query_is_pattern_rooted"

  external is_pattern_non_local :
    t -> int -> bool = "octs_query_is_pattern_non_local"

  external is_pattern_guaranteed_at_step :
    t -> int -> bool = "octs_query_is_pattern_guaranteed_at_step"

  external capture_name_for_id :
    t -> int -> string = "octs_query_capture_name_for_id"

  external capture_quantifier_for_id :
    t -> int -> int -> int = "octs_query_capture_quantifier_for_id"

  external string_value_for_id :
    t -> int -> string = "octs_query_string_value_for_id"

  external disable_capture :
    t -> string -> unit = "octs_query_disable_capture"

  external disable_pattern :
    t -> int -> unit = "octs_query_disable_pattern"
end

module QueryCursor = struct
  type t = ts_query_cursor

  external create : unit -> t = "octs_query_cursor_new"
  external delete : t -> unit = "octs_query_cursor_delete"

  external exec :
    t -> ts_query -> ts_node -> unit = "octs_query_cursor_exec"

  external did_exceed_match_limit :
    t -> bool = "octs_query_cursor_did_exceed_match_limit"

  external match_limit : t -> int = "octs_query_cursor_match_limit"

  external set_match_limit :
    t -> int -> unit = "octs_query_cursor_set_match_limit"

  external set_byte_range :
    t -> int -> int -> unit = "octs_query_cursor_set_byte_range"

  external set_point_range :
    t -> ts_point -> ts_point -> unit = "octs_query_cursor_set_point_range"

  external next_match :
    t -> ts_query_match option = "octs_query_cursor_next_match"

  external next_capture :
    t -> (ts_query_match * int) option = "octs_query_cursor_next_capture"

  external remove_match :
    t -> int -> unit = "octs_query_cursor_remove_match"

  external set_max_start_depth :
    t -> int -> unit = "octs_query_cursor_set_max_start_depth"
end

module Language = struct
  type t = ts_language

  external copy : t -> t = "octs_language_copy"
  external delete : t -> unit = "octs_language_delete"
  external symbol_count : t -> int = "octs_language_symbol_count"
  external state_count : t -> int = "octs_language_state_count"

  external symbol_name :
    t -> int -> string = "octs_language_symbol_name"

  external symbol_for_name :
    t -> string -> bool -> int = "octs_language_symbol_for_name"

  external field_count : t -> int = "octs_language_field_count"

  external field_name_for_id :
    t -> int -> string option = "octs_language_field_name_for_id"

  external field_id_for_name :
    t -> string -> int = "octs_language_field_id_for_name"

  external symbol_type : t -> int -> int = "octs_language_symbol_type"
  external version : t -> int = "octs_language_version"

  external next_state :
    t -> int -> int -> int = "octs_language_next_state"
end

module LookaheadIterator = struct
  type t = ts_lookahead_iterator

  external create :
    ts_language -> int -> t option = "octs_lookahead_iterator_new"

  external delete : t -> unit = "octs_lookahead_iterator_delete"

  external reset_state :
    t -> int -> bool = "octs_lookahead_iterator_reset_state"

  external reset :
    t -> ts_language -> int -> bool = "octs_lookahead_iterator_reset"

  external language : t -> ts_language = "octs_lookahead_iterator_language"
  external next : t -> bool = "octs_lookahead_iterator_next"

  external current_symbol :
    t -> int = "octs_lookahead_iterator_current_symbol"

  external current_symbol_name :
    t -> string = "octs_lookahead_iterator_current_symbol_name"
end
