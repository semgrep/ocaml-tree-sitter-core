/*
  semgrep-tsx

  Extends the standard tsx grammar with semgrep pattern constructs.
*/

const tsx_grammar =
      require('tree-sitter-typescript/tsx/grammar');

module.exports = grammar(tsx_grammar, {
  name: 'tsx',

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
