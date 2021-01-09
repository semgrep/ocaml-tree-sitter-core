/*
  semgrep-r

  Extends the standard r grammar with semgrep pattern constructs.
*/

const standard_grammar = require('tree-sitter-r/grammar');

module.exports = grammar(standard_grammar, {
  name: 'r',

  rules: {},
});
