module.exports = grammar({
  name: "choice",
  rules: {
    program: $ => choice(
      $.variable,
      $.number
    ),
    variable: $ => /\a\w*/,
    number: $ => /\d+/
  }
});
