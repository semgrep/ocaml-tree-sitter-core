module.exports = grammar({
  name: "repeat",
  rules: {
    program: $ => seq(
      $.variable,
      repeat(
        $.variable
      )
    ),
    variable: $ => /[a-z]+/
  }
});
