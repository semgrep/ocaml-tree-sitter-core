module.exports = grammar({
  name: "simple",
  rules: {
    program: $ => choice(
      $.variable,
      $.number
    ),
    variable: $ => /\a\w*/,
    number: $ => /\d+/
  }
});
