/*
 * semgrep-kotlin
 *
 * TODO: Extend the standard kotlin grammar with ellipsis and metavariable pattern constructs
 */

const standard_grammar = require('tree-sitter-kotlin/grammar');

module.exports = grammar(standard_grammar, {
    name: 'kotlin',

    rules: {

    }
});
