(*
   Extract ALIAS nodes and assign them globally-unique names.
*)

(*
   This returns pairs of the form (rule_name, aliases).
   Each alias.id can be used as a new rule name without conflicts.
*)
val extract_named_aliases :
  (string * Tree_sitter_t.rule_body) list ->
  (string * AST_grammar.alias list) list
