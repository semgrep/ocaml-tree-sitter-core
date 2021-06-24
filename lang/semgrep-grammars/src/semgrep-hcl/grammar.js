/*
  semgrep-hcl

  Extends the standard hcl grammar with semgrep pattern constructs.
*/

const base_grammar = require('tree-sitter-hcl/grammar');

module.exports = grammar(base_grammar, {
  name: 'hcl',

  conflicts: ($, previous) => previous.concat([
  ]),

  /*
     Support for semgrep ellipsis ('...') and metavariables ('$FOO'),
     if they're not already part of the base grammar.
  */
  rules: {
  /*
    semgrep_ellipsis: $ => '...',

    _expression: ($, previous) => {
      return choice(
        $.semgrep_ellipsis,
        ...previous.members
      );
    }
  */
  }
});
