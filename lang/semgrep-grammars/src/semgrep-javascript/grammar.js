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
    semgrep_ldots: $ => '<...',
    semgrep_rdots: $ => '...>',

    _expression: ($, previous) => {
      return choice(
        ...previous.members,

        // pfff: assignment_expr
        $.semgrep_dots,

        // pfff: primary_expr_no_braces
        $.semgrep_deep_expression,
      );
    },

    semgrep_deep_expression: $ => seq(
      $.semgrep_ldots, $._expression, $.semgrep_rdots
    ),

    // pfff: formal_parameter
    _formal_parameter: ($, previous) => {
      return choice(
        ...previous.members,
        $.semgrep_dots
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
        ...previous.members,
        //$.semgrep_dots,
        $.semgrep_for,
      );
    },

    // pfff: iteration_stmt
    semgrep_for: $ => seq(
      'for',
      '(',
      $.semgrep_dots,
      ')',
      $._statement // pfff: stmt1 (inline version of 'stmt')
    ),

    // pfff: xhp_attribute
    _jsx_attribute: ($, previous) => {
      return choice(
        ...previous.members,
        $.semgrep_dots,
      );
    },

    // pfff: xhp_attribute_value
    _jsx_attribute_value: ($, previous) => {
      return choice(
        ...previous.members,
        $.semgrep_dots,
      );
    },

    // The original grammar was the following. Unfortunately, it's not really
    // extensible. TODO: It would be more maintainable if the repeated item had
    // its own rule in tree-sitter-javascript.
    //
    // object: $ => prec(PREC.OBJECT, seq(
    //   '{',
    //   commaSep(optional(choice(
    //     $.pair,
    //     $.spread_element,
    //     $.method_definition,
    //     $.assignment_pattern,
    //     alias(
    //       choice($.identifier, $._reserved_identifier),
    //       $.shorthand_property_identifier
    //     )
    //   ))),
    //   '}'
    // )),
    //
    // pfff: object_literal, property_name_and_value
    object: $ => prec(-1 /* PREC.OBJECT */, seq(
      '{',
      commaSep(optional(choice(
        $.pair,
        $.spread_element,
        $.method_definition,
        $.assignment_pattern,
        alias(
          choice($.identifier, $._reserved_identifier),
          $.shorthand_property_identifier
        ),
        $.semgrep_dots, // added
      ))),
      '}'
    )),

  }
});

// copy-pasted from the original grammar
function commaSep1(rule) {
  return seq(rule, repeat(seq(',', rule)));
}

// copy-pasted from the original grammar
function commaSep(rule) {
  return optional(commaSep1(rule));
}
