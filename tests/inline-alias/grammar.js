module.exports = grammar({
  name: "inline_alias",
  rules: {
    program: $ => alias($._expr, $.expression),
    _expr: $ => choice(
      seq("(", $._expr, ")"),
      $.number
    ),
    number: $ => /[0-9]+/
  }
});
