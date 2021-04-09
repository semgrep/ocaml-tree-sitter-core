/*
 * semgrep-rust
 *
 * Extend the original tree-sitter Rust grammar with semgrep-specific constructs
 * used to represent semgrep patterns.
 */

const standard_grammar = require('tree-sitter-rust/grammar');

module.exports = grammar(standard_grammar, {
  name: 'rust',

  rules: {

    // Entry point
    source_file: ($, previous) => {
      return choice(
        previous,
        $.semgrep_expression,
        $.semgrep_statement,
      );
    },

    // Alternate "entry point". Allows parsing a standalone expression.
    semgrep_expression: $ => seq('__SEMGREP_EXPRESSION', $._expression),

    // Alternate "entry point". Allows parsing a standalone list of statements.
    semgrep_statement: $ => seq('__SEMGREP_STATEMENT', repeat1($._statement)),

    // Metavariables
    identifier: ($, previous) => {
      return token(
        choice(
          previous,
          /\$[A-Z_][A-Z_0-9]*/
        )
      );
    },

    // Statement ellipsis: '...' not followed by ';'
    _expression_statement: ($, previous) => {
      return choice(
        previous,
        prec.right(100, seq($.ellipsis, ';')),  // expression ellipsis
        prec.right(100, $.ellipsis),  // statement ellipsis
      );
    },

    // Expression ellipsis
    _expression: ($, previous) => {
      return choice(
        ...previous.members,
        $.ellipsis,
        $.deep_ellipsis
      );
    },

    deep_ellipsis: $ => seq(
      '<...', $._expression, '...>'
    ),

    ellipsis: $ => '...',
  }
});
