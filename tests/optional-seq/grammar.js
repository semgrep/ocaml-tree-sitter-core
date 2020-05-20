module.exports = grammar({
  name: "optional_seq",
  rules: {
    program: $ => optional(
      seq($.number, $.number, $.number)
    ),
    variable: $ => /[a-z]+/,
    number: $ => /\d+/
  }
});
