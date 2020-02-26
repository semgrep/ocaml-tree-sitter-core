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

let test_codegen_types = file => {
  let ast = Parse_grammar.parse(file);
  let nast = ast;
  print_string (Codegen_types.codegen(nast));
  print_string ("\n");
}

/*****************************************************************************/
/* Main entry for Arg */
/*****************************************************************************/

let actions = () => [
  ("-parse_grammar", "   <file>", Common.mk_action_1_arg(test_parse)),
  ("-codegen_types", "   <file>", Common.mk_action_1_arg(test_codegen_types)),
];