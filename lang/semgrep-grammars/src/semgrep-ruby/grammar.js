/*
  semgrep-ruby

  Extends the standard ruby grammar with semgrep pattern constructs.
*/

const standard_grammar = require('tree-sitter-ruby/grammar');

module.exports = grammar(standard_grammar, {
  name: 'ruby',

  rules: {
    /* Ruby global variables start with a '$' ('global_variable'). */

/*
    semgrep_dots: $ => '...',

    _expression: ($, previous) => {
      return choice(
        $.semgrep_dots,
        ...previous.members
      );
    }
*/
  }
});
