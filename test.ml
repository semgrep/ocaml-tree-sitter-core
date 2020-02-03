let test_parse_json_tree_sitter file =
  let json = Json_io.load_json file in
  let ast = 
    Parse_java_with_external_program.program_of_tree_sitter_json file json in

  (* just dump it back, to double check *)
  let v = Meta_ast_java.vof_any (Ast_java.AProgram ast) in
  let str = Ocaml.string_of_v v in
  pr str

let test_parse_file_tree_sitter file =
  let ast = Parse_java_with_external_program.parse file in

  (* just dump it back, to double check *)
  let v = Meta_ast_java.vof_any (Ast_java.AProgram ast) in
  let str = Ocaml.string_of_v v in
  pr str

  "-parse_json_tree_sitter", "   <file>", 
  Common.mk_action_1_arg test_parse_json_tree_sitter;
  "-parse_file_tree_sitter", "   <file>", 
  Common.mk_action_1_arg test_parse_file_tree_sitter;

  "-dump_java_tree_sitter", "   <file>", 
  Common.mk_action_1_arg test_dump_tree_sitter;


let test_dump_tree_sitter file =
  let sysline =  "node lang_java/tree_sitter/tree-sitter-parser.js " ^ file in 
  Sys.command sysline |> ignore
