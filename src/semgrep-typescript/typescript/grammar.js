/*
  semgrep-typescript

  Extends the standard typescript grammar with semgrep pattern constructs.
*/

const typescript_grammar =
      require('tree-sitter-typescript/typescript/grammar');

module.exports = grammar(typescript_grammar, {
  name: 'typescript',

/*
  conflicts: ($, previous) => previous.concat([
    [$.spread_element, $.semgrep_dots],
    [$._statement, $._expression]
  ]),
*/

  rules: {
    /*
      semgrep metavariables are already valid javascript/typescript
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
