(*
   Application's entrypoint.
*)

open Printf
open Cmdliner
open Ocaml_tree_sitter_gen

type config = {
  grammar : string;
  lang : string option;
  out_dir : string option;
}

let codegen config =
  let tree_sitter_grammar =
    Atdgen_runtime.Util.Json.from_file Tree_sitter_j.read_grammar
      config.grammar
  in
  let grammar = AST_grammar_conv.of_tree_sitter tree_sitter_grammar in
  Codegen.ocaml ?out_dir:config.out_dir ?lang:config.lang grammar

let grammar_term =
  let info =
    Arg.info []
      ~docv:"GRAMMAR_JSON"
      ~doc:"$(docv) is a file containing a tree-sitter grammar in json format.
            Its name is commonly 'grammar.json'. Try to not confuse it with
            'grammar.js' from which it is typically derived."
  in
  Arg.value (Arg.pos 0 Arg.file "grammar.json" info)

let lang_term =
  let info =
    Arg.info ["lang"; "l"]
      ~docv:"LANG"
      ~doc:"$(docv) is the name of the language described by the grammar.
            If specified, this name will appear in the generated file names.
            It must be a valid OCaml lowercase identifier."
  in
  Arg.value (Arg.opt Arg.(some string) None info)

let out_dir_term =
  let info =
    Arg.info ["out-dir"; "d"]
      ~docv:"DIR"
      ~doc:"$(docv) specifies where to put the output files. The default is
            the current directory."
  in
  Arg.value (Arg.opt Arg.(some string) None info)

let cmdline_term =
  let combine grammar lang out_dir =
    { grammar; lang; out_dir }
  in
  Term.(const combine
        $ grammar_term
        $ lang_term
        $ out_dir_term
       )

let doc =
  "derive ocaml code to interpret tree-sitter parsing output"

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
]

let parse_command_line () =
  let info =
    Term.info
      ~doc
      ~man
      "ocaml-tree-sitter"
  in
  match Term.eval (cmdline_term, info) with
  | `Error _ -> exit 1
  | `Version | `Help -> exit 0
  | `Ok config -> config

let safe_run config =
  try codegen config
  with
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

let main () =
  Printexc.record_backtrace true;
  let config = parse_command_line () in
  safe_run config

let () = main ()
