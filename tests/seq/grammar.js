module.exports = grammar({
  name: "seq",
  rules: {
    program: $ => seq(
      $.variable,
      $.number
    ),
    variable: $ => /[a-z]+/,
    number: $ => /\d+/
  }
});
