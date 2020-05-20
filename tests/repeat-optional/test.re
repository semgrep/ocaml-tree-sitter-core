open Common;
module CST = Ast;

let tests_path = "../../../../tests/list_and_option"

let test_end_to_end = (cst_json_file: string) => {
  print_string(spf("Parse CST in %s\n", cst_json_file));
  let program = Json_reader.parse(cst_json_file);
  print_string(CST.show_program(program));
}

let main = () => {
  let dir = tests_path;
  let cst_file = Filename.concat(dir, "ex1.json");
  let _ = test_end_to_end(cst_file);
}

let _ = main();