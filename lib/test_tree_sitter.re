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

let test_normalization_1 = _ => {
  /*
        CHOICE
        /    |
      SYMBOL(A)  CHOICE
            /    |
          SYMBOL(B)  SYMBOL(C)
  */
  let ex1 = (
    "ex1_grammar",
    [(
      "ex1_rule",
      A.CHOICE([
        A.SYMBOL("A"),
        A.CHOICE([A.SYMBOL("B"), A.SYMBOL("C")])
      ])
    )]
  );
  let expected_1 = (
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
  let ex1_normalized = Normalize_grammar.normalize(ex1);
  if (ex1_normalized == expected_1) {
    print_string("PASSED");
  } else {
    print_string("Expected ========= \n")
    print_string(B.show_grammar(expected_1) ++ "\n");
    print_string("ACTUAL =========\n")
    print_string(B.show_grammar(ex1_normalized) ++ "\n");
  }
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
  ("-test_normalization", "   <file>", Common.mk_action_1_arg(test_normalization_1)),
  ("-codegen_types", "   <file>", Common.mk_action_1_arg(test_codegen_types)),
  ("-codegen_jsonreader", "   <file>", Common.mk_action_1_arg(test_codegen_jsonreader)),
];
