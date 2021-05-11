(*
   Application's entrypoint.
*)
open Printf
open Cmdliner
open Tree_sitter_gen

type parse_conf = {
  lang : string;
  grammar : string;
  out_dir : string option;
}

type simplify_conf = {
  grammar: string;
  output_path: string;
}

type cmd_conf =
  | Parse of parse_conf
  | Simplify of simplify_conf

let safe_run f =
  try f with
    | Failure msg ->
      eprintf "\
    Error: %s
    Try --help.
    %!" msg;
          exit 1
    | e ->
          let trace = Printexc.get_backtrace () in
          eprintf "\
    Error: exception %s
    %s
    Try --help.
    %!"
   (Printexc.to_string e)
   trace;
   exit 1

let lang_term =
  let info =
    Arg.info []
      ~docv:"LANG"
      ~doc:"$(docv) is the name of the language described by the grammar.
            If specified, this name will appear in the generated file names.
            It must be a valid OCaml lowercase identifier."
  in
  Arg.required (Arg.pos 0 Arg.(some string) None info)

let grammar_term =
  let info = Arg.info []
      ~docv:"GRAMMAR_JSON"
      ~doc:"$(docv) is a file containing a tree-sitter grammar in json format.
            Its name is commonly 'grammar.json'. Try to not confuse it with
            'grammar.js' from which it is typically derived."
  in
  Arg.required (Arg.pos 1 Arg.(some file) None info)

let out_dir_term =
  let info =
    Arg.info ["out-dir"; "d"]
      ~docv:"DIR"
      ~doc:"$(docv) specifies where to put the output files. The default is
            the current directory."
  in
  Arg.value (Arg.opt Arg.(some string) None info)


let simplify_cmd = 
  let simplify = Simplify_grammar.run in

  let grammar_term =
    let info = Arg.info []
        ~docv:"GRAMMAR_JSON"
        ~doc:"$(docv) is a file containing a tree-sitter grammar in json format.
              Its name is commonly 'grammar.json'. Try to not confuse it with
              'grammar.js' from which it is typically derived."
    in
    Arg.required (Arg.pos 0 Arg.(some file) None info) in

  let output_file_term =
    let info = Arg.info []
        ~docv:"OUTPUT_FILE"
        ~doc:"$(docv) is a file containing the new tree-sitter grammar in json format.
          the main difference is that this file will expand all alias since ocaml-tree-sitter doest not support it."
  in
  Arg.required (Arg.pos 1 Arg.(some string) None info) in

  let doc =
    "simplify grammar.json for ocaml-tree-sitter" in

  let man = [
    `S Manpage.s_description;
    `P "simplify-grammar removes aliases and unhides hidden rules,
        for easier support by ocaml-tree-sitter.";
    `S Manpage.s_bugs;
    `P "Check out bug reports at
        https://github.com/returntocorp/ocaml-tree-sitter/issues.";
     ] in
  let info = Term.info ~doc ~man "simplify" in
  let cmdline_term = Term.(const (safe_run simplify) $ grammar_term $ output_file_term) in
  (cmdline_term, info)
  

let parse_cmd = 
  let codegen lang grammar out_dir =
    let tree_sitter_grammar =
      Atdgen_runtime.Util.Json.from_file Tree_sitter_j.read_grammar
        grammar
    in
    let grammar = CST_grammar_conv.of_tree_sitter tree_sitter_grammar in
    Codegen.ocaml ?out_dir ~lang grammar in

  let cmdline_term =
    Term.(
          const (safe_run codegen)
          $ lang_term
          $ grammar_term
          $ out_dir_term
        ) in
    

  let doc = "derive ocaml code to interpret tree-sitter parsing output" in
  let man = [
    `S Manpage.s_description;
    `P "ocaml-tree-sitter takes a tree-sitter grammar and generates OCaml
      for reading tree-sitter parsing output. The input grammar is in
      json format, commonly under the file name 'grammar.json'.
      tree-sitter itself is used separately to generate the actual C parser
      from the json grammar. The generated OCaml code is meant to be used
      to process the output of such a parser.";
      `S Manpage.s_bugs;
      `P "Check out bug reports at
      https://github.com/returntocorp/ocaml-tree-sitter/issues.";
    ] in
  let version = "0.0.0" in
  let info = Term.info ~version ~doc ~man "ocaml-tree-sitter" in

  (cmdline_term, info)


let subcommands = [simplify_cmd]


let () = 
  Printexc.record_backtrace true;
  Term.(exit @@ eval_choice parse_cmd subcommands)
