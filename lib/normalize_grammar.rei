
module A = Ast_grammar;
module B = Ast_grammar_normalized;

let normalize_to_simple: A.rule_body => (
  B.simple,
  list((string, A.rule_body))
)

let normalize_to_atom: A.rule_body => (
  B.atom,
  list((string, A.rule_body))
)

let normalize_body: A.rule_body => (
  B.rule_body,
  list((string, A.rule_body))
)


let normalize_rule: ((string, A.rule_body)) => list(
  (string, B.rule_body)
)

let normalize_rules: list((string, A.rule_body)) => list(
  (string, B.rule_body)
)

let normalize: A.t => B.t;