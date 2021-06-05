/*
  semgrep-hack

  Extends the standard hack grammar with semgrep pattern constructs.
*/

// The npm package is 'tree-sitter-hacklang', not 'tree-sitter-hack',
// because npm doesn't like the word 'hack'. See original note in the
// project's readme.
//
const base_grammar = require('tree-sitter-hacklang/grammar');

module.exports = grammar(base_grammar, {
  name: 'hack',

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
