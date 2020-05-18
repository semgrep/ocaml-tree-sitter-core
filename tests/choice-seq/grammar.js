module.exports = grammar({
  name: "choice_seq",
  rules: {
    program: $ => seq(
      choice(
        $.number,
        $.variable
      ),
      $.number
    ),
    variable: $ => /[a-z]+/,
    number: $ => /\d+/
  }
});
