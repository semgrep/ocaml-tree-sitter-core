module A = Ast_grammar
module B = Ast_grammar_normalized
let test_parse file =
  let ast = Parse_grammar.parse file in
  let s = A.show_grammar ast in print_string s
let test_codegen_types file =
  let ast = Parse_grammar.parse file in
  let nast = ast in
  print_string (Codegen_types.codegen nast); print_string "\n"
let actions () =
  [("-parse_grammar", "   <file>", (Common.mk_action_1_arg test_parse));
  ("-codegen_types", "   <file>",
    (Common.mk_action_1_arg test_codegen_types))]