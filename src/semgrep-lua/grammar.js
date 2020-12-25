/*
 * semgrep-kotlin
 *
 * TODO: Extend the standard lua grammar with ellipsis and metavariable pattern constructs
 */

const standard_grammar = require('tree-sitter-lua/grammar');

module.exports = grammar(standard_grammar, {
    name: 'lua',

    rules: {

    }
});
