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
        identifier: $ => /\$?[a-zA-Z_][a-zA-Z_0-9]*/
    }
});
