/*
 * semgrep-csharp
 *
 * Extend the original tree-sitter C# grammar with semgrep-specific constructs
 * used to represent semgrep patterns.
 *
 * The language is renamed from c-sharp to csharp to match language name
 * conventions in ocaml-tree-sitter and semgrep.
 */

const standard_grammar = require('tree-sitter-c-sharp/grammar');

module.exports = grammar(standard_grammar, {
  /*
    We can't rename the grammar to 'csharp' because it relies on a custom
    lexer ('scanner.c') which comes with the inherited grammar and provides
    a function 'tree_sitter_c_sharp_external_scanner_create'.
    The code generator ('tree-sitter generate') however expects this function
    name to match the grammar name, so if we rename it here to 'csharp',
    it will generate glue code that calls
    'tree_sitter_csharp_external_scanner_create'
    while only 'tree_sitter_c_sharp_external_scanner_create' is available.
  */
  name: 'c_sharp',

  rules: {

    // Entry point
    compilation_unit: ($, previous) => {
      return choice(
        previous,
        $.semgrep_expression
      );
    },

    // Alternate "entry point". Allows parsing a standalone expression.
    semgrep_expression: $ => seq('__SEMGREP_EXPRESSION', $._expression),

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
    expression_statement: ($, previous) => {
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
