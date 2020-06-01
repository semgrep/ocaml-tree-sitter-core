module.exports = grammar({
  name: "backtrack_choice",
  rules: {
    program: $ => choice(
      $.number,
      seq($.number, $.number)
    ),
    number: $ => /[0-9]+/
  }
});
