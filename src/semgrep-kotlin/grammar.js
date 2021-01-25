/*
 * semgrep-kotlin
 *
 * Extend the standard kotlin grammar with metavariable pattern constructs.
 * Ellipsis are in the kotlin grammar, so no need to extend for ellipsis.
 */

const standard_grammar = require('tree-sitter-kotlin/grammar');

module.exports = grammar(standard_grammar, {
    name: 'kotlin',

    rules: {

        // Entry point
        source_file: ($, previous) => {
          return choice(
            previous,
            $.semgrep_expression
          );
        },
    
        // Alternate "entry point". Allows parsing a standalone expression.
        semgrep_expression: $ => seq('__SEMGREP_EXPRESSION', $._expression),

        // Metavariables
        simple_identifier: ($, previous) => {
            return choice(
                previous,
                /\$[a-zA-Z_][a-zA-Z_0-9]*/
            )
        },
        
        // Statement ellipsis: '...' not followed by ';'
        _expression: ($, previous) => {
            return choice(
                previous,
                $.ellipsis,  // statement ellipsis
            );
        },

        ellipsis: $ => '...',
    }
});