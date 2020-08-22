(*
   Add grammar rules to ensure that no pattern remains anonymous.

   The problem is that tree-sitter won't return a node if the pattern
   doesn't have a name. A rule consisting only of a pattern such as

     foo: $ => /[a-z]+/,

   allows the token to receive a name, 'foo' in this example.
*)

val assign_names_to_patterns : Tree_sitter_t.grammar -> Tree_sitter_t.grammar
