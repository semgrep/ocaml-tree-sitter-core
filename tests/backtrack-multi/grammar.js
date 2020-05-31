module.exports = grammar({
  name: "backtrack_multi",
  /*
    The following inputs should match:
    - 1 2 3
    - 1 2 3 4
    - 1 2 3 4 5
   */
  rules: {
    program: $ => seq(
      choice(seq($.number, $.number), $.number),  // longest match first
      choice($.number, seq($.number, $.number)),  // shortest match first
      $.number
    ),
    number: $ => /[0-9]+/
  }
});
