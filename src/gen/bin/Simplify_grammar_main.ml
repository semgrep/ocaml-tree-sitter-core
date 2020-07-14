(*
    Command-line utility for simplify a tree-sitter grammar.json
    into one supported by ocaml-tree-sitter.
*)

open Printf
open Cmdliner
open Tree_sitter_gen

type config = unit

let cmdline_term =
  let combine () =
    ()
  in
  Term.(const combine)

let doc =
  "simplify grammar.json for ocaml-tree-sitter"

let man = [
  `S Manpage.s_description;
  `P "simplify-grammar removes aliases and unhides hidden rules,
      for easier support by ocaml-tree-sitter.";
  `S Manpage.s_bugs;
  `P "Check out bug reports at
      https://github.com/returntocorp/ocaml-tree-sitter/issues.";
]

let parse_command_line () =
  let info =
    Term.info
      ~doc
      ~man
      "simplify-grammar"
  in
  match Term.eval (cmdline_term, info) with
  | `Error _ -> exit 1
  | `Version | `Help -> exit 0
  | `Ok config -> config

let safe_run _config =
  try Simplify_grammar.run stdin stdout
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
