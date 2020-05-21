module.exports = grammar({
  name: "name_alias",
  rules: {
    program: $ => optional(
      alias($.numbers, $.thing)
    ),
    numbers: $ => repeat1($.number),
    number: $ => /[0-9]+/
  }
});
