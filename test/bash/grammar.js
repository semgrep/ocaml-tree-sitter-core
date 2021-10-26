const SPECIAL_CHARACTERS = [
  "'", '"',
  '<', '>',
  '{', '}',
  '\\[', '\\]',
  '(', ')',
  '`', '$',
  '|', '&', ';',
  '\\',
  '\\s',
  '#',
];

module.exports = grammar({
  name: 'bash',

  inline: $ => [
    $._literal,
    $._primary_expression,
    $._simple_variable_name,
    $._special_variable_name,
  ],

  externals: $ => [
    $._empty_value,
    $._concat,
    $.variable_name, // Variable name followed by an operator like '=' or '+='
    '}',
    ']',
    '<<',
    '<<-',
    '\n',
  ],

  extras: $ => [
    /\s/,
    /\\\r?\n/,
    /\\( |\t|\v|\f)/
  ],

  rules: {
    program: $ => optional($.command),

    // Commands

    command: $ => prec.left(seq(
      field('name', $.command_name),
      repeat(field('argument', $._literal))
    )),

    command_name: $ => $._literal,

    // Literals

    _literal: $ => choice(
      $.concatenation,
      $._primary_expression,
      alias(prec(-2, repeat1($._special_character)), $.word)
    ),

    _primary_expression: $ => choice(
      $.word,
//      $.string,
//      $.raw_string,
//      $.ansii_c_string,
//      $.expansion,
      $.simple_expansion,
//      $.string_expansion,
//      $.command_substitution,
//      $.process_substitution // if removed: thread 'main' panicked at 'no entry found for key'
    ),

    concatenation: $ => prec(-1, seq(
      choice(
        $._primary_expression,
        $._special_character,
      ),
      repeat1(prec(-1, seq(
        $._concat,
        choice(
          $._primary_expression,
          $._special_character,
        )
      ))),
      optional(seq($._concat, '$'))
    )),

    _special_character: $ => token(prec(-1, choice('{', '}', '[', ']'))),

    array: $ => seq(
      '(',
      repeat($._literal),
      ')'
    ),

    simple_expansion: $ => seq(
      '$',
      choice(
        $._simple_variable_name,
        $._special_variable_name,
        alias('!', $.special_variable_name),
        alias('#', $.special_variable_name)
      )
    ),

    _simple_variable_name: $ => alias(/\w+/, $.variable_name),

    _special_variable_name: $ => alias(choice('*', '@', '?', '-', '$', '0', '_'), $.special_variable_name),

    word: $ => token(repeat1(choice(
      noneOf(...SPECIAL_CHARACTERS),
      seq('\\', noneOf('\\s'))
    ))),
  }
});

function noneOf(...characters) {
  const negatedString = characters.map(c => c == '\\' ? '\\\\' : c).join('')
  return new RegExp('[^' + negatedString + ']')
}
