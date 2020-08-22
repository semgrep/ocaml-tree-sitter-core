(*
   Assign good names to productions in the grammar, based on the
   enclosing rule name and the contents of the production.
*)

val name_rule_body : CST_grammar.rule_body -> string

(*
   Assign constructor names suitable for classic variants and polymorphic
   variants, from rule bodies. The containing rule name is only for
   better error messages.
*)
val assign_case_names :
  ?rule_name: string ->
  CST_grammar.rule_body list ->
  (string * CST_grammar.rule_body) list

(* Produce a string of 7 hexadecimal digits.
   This is meant for suggesting stable IDs for arbitrary strings. *)
val hash_string_hex : string -> string
