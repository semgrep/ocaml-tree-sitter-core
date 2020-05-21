module.exports = grammar({
  name: "string_alias",
  rules: {
    program: $ => optional(
      alias('hello', 'hi')
    )
  }
});
