let codegen: (
  Ast_grammar_normalized.t,
  list((string, Ast_grammar_normalized.simple)),
  string
) => string