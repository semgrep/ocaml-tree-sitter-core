(*
   Assign good names to productions in the grammar, based on the
   enclosing rule name and the contents of the production.
*)

val name_rule_body : CST_grammar.rule_body -> string

val assign_case_names :
  string option ->
  CST_grammar.rule_body list ->
  (string * CST_grammar.rule_body) list
