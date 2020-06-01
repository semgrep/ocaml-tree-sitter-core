module.exports = grammar({
  name: "backtrack_opt",
  rules: {
    program: $ => seq(
      optional($.number),
      $.number
    ),
    number: $ => /[0-9]+/
  }
});
