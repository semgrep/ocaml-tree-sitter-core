module.exports = grammar({
  name: "alias_scope",
  rules: {
    program: $ => seq(
      alias($.number, $.elt),
      alias($.pair, $.elt)
    ),
    pair: $ => seq($.number, $.number),
    number: $ => /[0-9]+/
  }
});
