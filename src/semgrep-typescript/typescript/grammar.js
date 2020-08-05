/*
  semgrep-typescript
*/

module.exports = grammar(require('tree-sitter-typescript/typescript/grammar'), {
  name: 'typescript',
  dots: '...',
  _expression: ($, previous) => {
    const choices = [
      $.dots
    ];
    choices.push(...previous.members);
    return choice(...choices);
  }
});
