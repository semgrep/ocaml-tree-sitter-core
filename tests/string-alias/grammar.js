module.exports = grammar({
  name: "string_alias",
  rules: {
    program: $ => optional(
      alias(repeat1($.number), '*')
    ),
    number: $ => /[0-9]+/
  }
});
