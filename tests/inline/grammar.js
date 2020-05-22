module.exports = grammar({
  name: "inline",
  rules: {
    program: $ => $._expr,
    _expr: $ => choice(
      seq("(", $._expr, ")"),
      $.number
    ),
    number: $ => /[0-9]+/
  }
});
