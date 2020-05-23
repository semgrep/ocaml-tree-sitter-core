module.exports = grammar({
  name: "hide_token",
  /*
    The goal of this test was to show that ocaml-tree-sitter can handle aliases
    starting with an underscore.

    It turns out such aliases are not omitted in tree-sitter's output,
    which looks like a bug.
   */
  rules: {
    program: $ => seq(
      alias($.visible_number, $._hidden_number),  // omitted from json output?
      $.visible_number,                           // present in json output
    ),
    visible_number: $ => /[0-9]+/
  }
});
