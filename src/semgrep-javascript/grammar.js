/*
  semgrep-javascript

  Extends the standard javascript grammar with semgrep pattern constructs.
*/

const javascript_grammar = require('tree-sitter-javascript/grammar');

module.exports = grammar(javascript_grammar, {
  name: 'javascript',

/*
  conflicts: ($, previous) => previous.concat([
    [$.spread_element, $.semgrep_dots],
    [$.rest_parameter, $.semgrep_dots],
    [$.rest_parameter, $.spread_element, $.semgrep_dots],
    [$._statement, $._expression]
  ]),
*/

  rules: {
    /*
      semgrep metavariables are already valid javascript
      identifiers so we do nothing for them.
    */
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
