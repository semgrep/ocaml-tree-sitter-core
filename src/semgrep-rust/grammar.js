/*
 * semgrep-rust
 *
 * Extend the standard rust grammar with metavariable pattern constructs.
 * There is no need to extend it for ellipsis because ellipsis are already
 * part of the Rust language.
 */

const standard_grammar = require('tree-sitter-rust/grammar');

module.exports = grammar(standard_grammar, {
    name: 'rust',

    rules: {}
});
