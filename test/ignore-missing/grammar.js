module.exports = grammar({
  name: "ignore_missing",
  rules: {
    program: $ => repeat($.tuple),

    tuple: $ => choice(
      seq(
        'a', $.terminator
      ),
      seq(
        'b', ';'
      ),
    ),
    terminator: $ => /[;?.]+/
  }
});
