module.exports = grammar({
  name: "unhide_token",
  rules: {
    program: $ => seq(
      $._hidden_number,                           // omitted from json output
      alias($._hidden_number, $.visible_number)   // present in json output
    ),
    _hidden_number: $ => /[0-9]+/
  }
});
