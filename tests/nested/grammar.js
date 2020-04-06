module.exports = grammar({
  name: "arithmetic",

  extras: $ => [$.comment, /\s/],

  rules: {
    program: $ => repeat(choice(
      $.assignment_statement,
      $.expression_statement
    )),

    assignment_statement: $ => seq(
        seq($.variable, "="), 
        seq($.expression, ";"),
    ),

    expression_statement: $ => seq(
      $.expression, ";"
    ),

    expression: $ => choice(
      $.variable,
      $.number,
        choice(
        prec.left(1, seq($.expression, "+", $.expression)),
        prec.left(1, seq($.expression, "-", $.expression)),
        ),
        choice(
         prec.left(2, seq($.expression, "*", $.expression)),
         prec.left(2, seq($.expression, "/", $.expression)),
         prec.left(3, seq($.expression, "^", $.expression))
        ),
    ),

    variable: $ => /\a\w*/,

    number: $ => /\d+/,

    comment: $ => /#.*/
  }
});
