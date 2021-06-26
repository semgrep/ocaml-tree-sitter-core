module.exports = grammar({
  name: "extras",
  rules: {
    program: $ => repeat(
      $.number
    ),
    number: $ => /[0-9]+/,
    comment: $ => /#.*/
  },
  extras: $ => [
    $.comment,
    /\s|\\\n/
  ]
})
