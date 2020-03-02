/*
  Code-generator that take specified grammar file
  and produces JSON parser using Json_wheel that
  - input: a CST file from tree-sitter
  - output: an data type instance for the grammar using the given grammar name
 */
let codegen: (
  Ast_grammar_normalized.t, /* NAST of the grammar */
  list((string, Ast_grammar_normalized.simple)), /* list of intermediate nodes generated during codegen_types*/
  string /* grammar AST name.e.g. file name for the output of codegen_types */
) => string