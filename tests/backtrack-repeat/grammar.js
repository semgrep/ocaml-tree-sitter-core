module.exports = grammar({
  name: "backtrack_repeat",
  rules: {
    program: $ => seq(
      repeat1($.number),
      $.number
    ),
    number: $ => /[0-9]+/
  }
});
