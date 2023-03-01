module.exports = grammar({
  name: "externals",

  /**
   * We want to test our ability to deal with externals.  
   */
  externals: $ => [
    "foo",
    /\n/,
    $.bar
  ],

  rules: {
    // used to be bad:
    // program: ($) => seq('a', $.extra),

    // good:
    program: ($) => repeat(choice("foo", /\n/, $.bar))
  },
});
