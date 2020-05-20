module.exports = grammar({
  name: "list_and_option",

  extras: $ => [
    /\s/
  ],

  word: $ => $.identifier,

  rules: {
      program: $ => seq($.a_rule, 
                        repeat($.b_rule), 
                        optional($.c_rule), 
                        $.d_rule, 
                        $.e_rule_alias,
                        $.f_rule_alias
                       ),

      e_rule_alias: $ => seq($.e_rule),
      f_rule_alias: $ => $.f_rule,
                        
      a_rule: $ => 'a',
      b_rule: $ => 'b',
      c_rule: $ => 'c',
      d_rule: $ => 'd',
      e_rule: $ => 'e',
      f_rule: $ => 'f',

      // this does not work! cant use intermediate
      // seq($.a, $.b_s, $.maybe_c, $.d),
      // b_s: $ => repeat($.b),
      // maybe_c: $ => seq($.c),

     identifier: $ => /[a-zA-Z_]\w*/,
  }
});
