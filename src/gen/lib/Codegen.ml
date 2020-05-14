(*
   Emit code.
*)

open Printf

let save filename data =
  let oc = open_out filename in
  output_string oc data;
  close_out oc

let mkpath opt_dir filename =
  match opt_dir with
  | None -> filename
  | Some dir -> Filename.concat dir filename

let ocaml ?out_dir ?lang grammar =
  let lang_suffix =
    match lang with
    | None -> ""
    | Some s -> "_" ^ s
  in
  let ast_module = sprintf "AST%s" lang_suffix in
  let parse_module = sprintf "Parse%s" lang_suffix in
  let ast_file = mkpath out_dir (sprintf "%s.ml" ast_module) in
  let parse_file = mkpath out_dir (sprintf "%s.ml" parse_module) in

  let ast_code = Codegen_AST.generate grammar in
  let parse_code = Codegen_parse.generate grammar in
  save ast_file ast_code;
  save parse_file parse_code
