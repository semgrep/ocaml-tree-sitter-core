let codegen: (
  Ast_grammar_normalized.t,
  list((string, Ast_grammar_normalized.rule_body)),
  string
) => string