module.exports = grammar({
  name: "extras",
  rules: {
    program: $ => repeat(
      $.number
    ),
    number: $ => /[0-9]+/,
    comment: $ => /#.*/,
    complex_extra: $ => seq('(', repeat($.number), ')'),
  },
  extras: $ => [
    $.comment,       // appears in the CST
    $.complex_extra, // same
    "IGNOREME",  // doesn't appear in the CST because it doesn't have a name
    /\s|\\\n/    // same
  ]
})
