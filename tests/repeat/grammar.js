module.exports = grammar({
  name: "repeat",
  rules: {
    program: $ => repeat(
      $.variable
    ),
    variable: $ => /[a-z]+/
  }
});
