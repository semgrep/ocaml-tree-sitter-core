module.exports = grammar({
  name: "simple",
  rules: {
    program: $ => repeat(
      $.variable
    ),
    variable: $ => /\a\w*/
  }
});
