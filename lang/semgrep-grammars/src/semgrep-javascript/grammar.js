/*
  semgrep-javascript

  Extends the standard javascript grammar with semgrep pattern constructs.

  Semgrep metavariables are already valid javascript
  identifiers so we do nothing for them.
*/

const javascript_grammar = require('tree-sitter-javascript/grammar');

module.exports = grammar(javascript_grammar, {
  name: 'javascript',


  conflicts: ($, previous) => previous.concat([

    // conflicts between semgrep ellipsis and spread elements
    [$.spread_element, $.rest_parameter, $.semgrep_dots],
    [$.rest_parameter, $.semgrep_dots],
    [$.spread_element, $.semgrep_dots],
  ]),

  rules: {

    /*
       We create multiple "entry points" so as to allow different kinds of
       semgrep patterns, prefixed with some new keyword.
    */
/*
    program: ($, previous) => choice(
      ...previous.members,
      seq('__SEMGREP_EXPRESSION', $._expression),
    ),
*/

    semgrep_dots: $ => '...',

    // pfff: assignment_expr
    _expression: ($, previous) => {
      return choice(
        $.semgrep_dots,
        ...previous.members
      );
    },
/*
    // pfff: formal_parameter
    _formal_parameter: ($, previous) => {
      return choice(
        $.semgrep_dots,
        ...previous.members
      );
    },

    // pfff: class_element (repeated in the class body)
    class_body: $ => seq(
      '{',
      repeat(choice(
        seq(field('member', $.method_definition), optional(';')),
        seq(field('member', $.public_field_definition), $._semicolon),
        $.semgrep_dots,
      )),
      '}'
    ),

    // pfff: stmt
    _statement: ($, previous) => {
      return choice(
        $.semgrep_dots,
        $.semgrep_for,
        ...previous.members
      );
    },

    // pfff: iteration_stmt
    semgrep_for: $ => seq(
      '(',
      $.semgrep_dots,
      ')',
      $._statement // pfff: stmt1 (inline version of 'stmt')
    ),
*/
  }
});
