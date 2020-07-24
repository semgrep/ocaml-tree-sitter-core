(*
   Undo the duplications introduced by the 'inline' field of the grammar
   so as to recover the original names of anonymous nodes.

   This inlining must occur in the grammar so as to avoid parsing conflicts.
   It is not just "useful for rules that are used in multiple places but
   for which you don’t want to create syntax tree nodes at runtime" as stated
   in the tree-sitter manual (2020-07-24).

   However, there seems to be an equivalence between a rule name that starts
   with an underscore ('_inline_me') and any rule name listed in the
   'inline' section of the grammar, with or without an underscore.
   In both cases, '_inline_me: ...' and 'rules: $ => [ $.inline_me ]' yield
   a CST that lacks a node with that name.

   Since we don't support hidden rules to simplify our parsing ('Parse.ml'),
   our 'grammar.json' is always pre-processed to prevent hidden/inlined
   rules. Our solution is to perform the inlining ourselves, resulting
   in duplicated grammar nodes. See 'Simplify_grammar.ml'.

   Here we are concerned with recovering the original names of the
   grammar nodes that we inlined in 'grammar.json'. The named rules
   that were inlined were left in the grammar even though they're
   unreachable from the grammar's entry point. This allows us to
   deinline them, i.e. recover the structure of the original grammar
   before inlining.
*)

let deinline_rules grammar =
  Factorize.factorize_rules
    ~create_names:false
    ~min_uses:0
    ~min_size:0
    grammar
