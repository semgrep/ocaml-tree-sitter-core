/* Yoann Padioleau
 *
 * Copyright (C) 2020 r2c
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License (GPL)
 * version 2 as published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * file license.txt for more details.
 */

module A = Ast_grammar;
module B = Ast_grammar_normalized;

/*****************************************************************************/
/* Subsystem testing */
/*****************************************************************************/
let test_parse = file => {
  let ast = Parse_grammar.parse(file);
  let s = A.show_grammar(ast);
  print_string(s);
}

let test_normalize = file => {
  let ast = Parse_grammar.parse(file);
  let nast = Normalize_grammar.normalize(ast);
  let s = B.show_grammar(nast);
  print_string(s);
}

let _test_normalization = (ex1, expected_1) => {
  let ex1_normalized = Normalize_grammar.normalize(ex1);
  if (ex1_normalized == expected_1) {
    print_string("PASSED\n");
  } else {
    print_string("Expected ========= \n")
    print_string(B.show_grammar(expected_1) ++ "\n");
    print_string("ACTUAL =========\n")
    print_string(B.show_grammar(ex1_normalized) ++ "\n");
  }
}

let test_normalization_4 = _ => {
  /*
               CHOICE
              / |   \   \
        SEQ  SYMBOL(A) SYMBOL(B) SEQ
        /\                       /\
    SYMBOL(C) STRING(D)   SYMBOL(E) STRING(F)
  */
  let grammar = (
    "ex4",
    [(
      "arith_expression",
      A.CHOICE([
        A.SEQ([
          A.SYMBOL("C"),
          A.STRING("D"),
        ]),
        A.SYMBOL("A"),
        A.SYMBOL("B"),
        A.SEQ([
          A.SYMBOL("E"),
          A.STRING("F"),
        ])
      ])
    )]
  );
  let expected = (
    "ex4",
    [(
      "arith_expression",
      B.CHOICE([
        B.SEQ([
          B.SYMBOL("C"),
          B.SYMBOL("D")
        ]),
        B.ATOM(B.SYMBOL("A")),
        B.ATOM(B.SYMBOL("B")),
        B.SEQ([
          B.SYMBOL("E"),
          B.SYMBOL("F")
        ])
      ])
    )]
  );
  _test_normalization(grammar, expected);
}

let test_normalization_3 = _ => {
  /*
             CHOICE
              / |
        CHOICE TOKEN
        /  \
    CHOICE TOKEN
      /  \
  CHOICE  TOKEN
    |
  TOKEN
  */
  let grammar = (
    "ex3_grammar",
    [(
      "ex3_rule",
      A.CHOICE([
        A.CHOICE([
          A.CHOICE([
            A.CHOICE([
              A.TOKEN
            ]),
            A.TOKEN,
          ]),
          A.TOKEN
        ]),
        A.TOKEN,
      ])
    )]
  );
  let expected = (
    "ex3_grammar",
    [
      (
        "ex3_rule",
        B.CHOICE([
          B.ATOM(B.SYMBOL("intermediate1")),
          B.ATOM(B.TOKEN),
        ])
      ),
      (
        "intermediate1",
        B.CHOICE([
          B.ATOM(B.SYMBOL("intermediate2")),
          B.ATOM(B.TOKEN),
        ])
      ),
      (
        "intermediate2",
        B.CHOICE([
          B.ATOM(B.SYMBOL("intermediate3")),
          B.ATOM(B.TOKEN),
        ])
      ),
      (
        "intermediate3",
        B.CHOICE([
          B.ATOM(B.TOKEN),
        ])
      ),
    ]
  );
  _test_normalization(grammar, expected);

}

let test_normalization_2 = _ => {
  /*
              SEQ
             / | \
      CHOICE TOKEN SYMBOL(A)
       /  \
  SYMBOL(B) TOKEN
  */
  let grammar = (
    "ex2_grammar",
    [(
      "ex2_rule",
      A.SEQ([
        A.CHOICE([A.SYMBOL("B"), A.TOKEN]),
        A.TOKEN,
        A.SYMBOL("A")
      ])
    )]
  );
  let expected = (
    "ex2_grammar",
    [
      (
        "ex2_rule",
        B.SIMPLE(B.SEQ([
          B.SYMBOL("intermediate1"),
          B.TOKEN,
          B.SYMBOL("A")
        ]))
      ),
      (
        "intermediate1",
        B.CHOICE([
          B.ATOM(B.SYMBOL("B")),
          B.ATOM(B.TOKEN),
        ])
      )
    ]
  );
  _test_normalization(grammar, expected);
}

let test_normalization_1 = _ => {
  /*
        CHOICE
        /    |
      SYMBOL(A)  CHOICE
            /    |
          SYMBOL(B)  SYMBOL(C)
  */
  let grammar = (
    "ex1_grammar",
    [(
      "ex1_rule",
      A.CHOICE([
        A.SYMBOL("A"),
        A.CHOICE([A.SYMBOL("B"), A.SYMBOL("C")])
      ])
    )]
  );
  let expected = (
    "ex1_grammar",
    [
      (
        "ex1_rule",
        B.CHOICE([
          B.ATOM(B.SYMBOL("A")),B.ATOM(B.SYMBOL("intermediate1"))
        ])
      ),
      (
        "intermediate1",
        B.CHOICE([
          B.ATOM(B.SYMBOL("B")),
          B.ATOM(B.SYMBOL("C")),
        ])
      )
    ]
  );
  _test_normalization(grammar, expected);
}

let test_normalization = _ => {
  test_normalization_1();
  test_normalization_2();
  test_normalization_3();
  test_normalization_4();
}

let test_codegen_types = file => {
  let ast = Parse_grammar.parse(file);
  let nast = Normalize_grammar.normalize(ast);
  print_string (Codegen_types.codegen(nast));
  print_string ("\n");
}

let test_codegen_jsonreader = file => {
  let ast = Parse_grammar.parse(file);
  let nast = Normalize_grammar.normalize(ast);
  print_string (Codegen_json_reader.codegen(nast));
  print_string("\n")
}

/*****************************************************************************/
/* Main entry for Arg */
/*****************************************************************************/

let actions = () => [
  ("-parse_grammar", "   <file>", Common.mk_action_1_arg(test_parse)),
  ("-normalize_grammar", "   <file>", Common.mk_action_1_arg(test_normalize)),
  ("-test_normalization", "   <file>", Common.mk_action_1_arg(test_normalization)),
  ("-codegen_types", "   <file>", Common.mk_action_1_arg(test_codegen_types)),
  ("-codegen_jsonreader", "   <file>", Common.mk_action_1_arg(test_codegen_jsonreader)),
];
