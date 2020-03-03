/*
  Code-generator that take specified grammar file
  and produces an data type definitions for the grammar.
  Produces a list of intermediate nodes and their structure.
*/
let codegen: Ast_grammar_normalized.t => (
  string, /* name of the intermediate node that was created during grammar ADT generation */
  list((string, Ast_grammar_normalized.simple)) /* list of intermediate nodes */
);