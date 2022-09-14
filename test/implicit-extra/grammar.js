/*
 * Test the case where extras also appear in ordinary rules.
 */
module.exports = grammar({
  name: 'implicit_extra',

  extras: ($) => [
    $.comma,
    $.period,
    "\n",  // check that literals are tolerated
    /a*/,  // check that patterns are tolerated
  ],

  rules: {
    program: ($) => $.foos,
    foos: ($) => seq(
      $.foo,
      repeat(
        seq(
          choice($.comma, $.period, $.semi),
          $.foo,
        )
      )
    ),
    foo: ($) => 'foo',
    comma: ($) => ',',
    semi: ($) => ';',
    period: ($) => '.',

    // Check that name collision avoidance works
    comma_explicit: ($) => 'unused',
    dummy_alias0: ($) => 'unused',

    // This should get another type name than 'extra'
    extra: ($) => 'unused',
  }
});
