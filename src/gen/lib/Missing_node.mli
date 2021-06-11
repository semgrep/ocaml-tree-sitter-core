(*
   Add grammar rules to ensure that no pattern remains anonymous.

   The problem is that tree-sitter won't return a node if the pattern
   doesn't have a name. A rule consisting only of a pattern such as

     foo: $ => /[a-z]+/,

   allows the token to receive a name, 'foo' in this example.

   This is applied to some token() constructs as well.
*)
val work_around_missing_nodes : Tree_sitter_t.grammar -> Tree_sitter_t.grammar

type token_node_name =
  | Literal of string
  | Name of string

(*
   Some token() constructs known to produce no node must be left in place
   due to containing precedence annotations. This function is meant
   for steps that consume the CST and need to know whether a node should
   be expected.

   The name of the node is returned iff a node will exist.
*)
val token_produces_node : Tree_sitter_t.rule_body -> token_node_name option
