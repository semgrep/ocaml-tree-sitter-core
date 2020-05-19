(*
   Representation of an AST, as derived from a grammar definition.
   This representation is meant to be straightforward to translate to
   Reason/OCaml type definitions.

   A raw grammar definition as expressed in a grammar.json file is readable
   and writable using the Tree_sitter_t and Tree_sitter_j modules derived
   from Tree_sitter.atd.

   The representation offered in this file is an irreversible view on
   a grammar.json file. In particular:
   - precedence annotations are removed
   - nested anonymous rules such as nested sequences and nested alternatives
     are flattened whenever possible
   - various fields from the original grammar are ignored
   - there's room for future modifications

   TODO: clarify what we intend to do with this
*)

val of_tree_sitter : Tree_sitter_t.grammar -> AST_grammar.t
