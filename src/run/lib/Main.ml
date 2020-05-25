(**
   Entrypoint for a standalone parser-dumper, to be called by generated
   parsers.
*)

open Printf

let safe_run f =
  Printexc.record_backtrace true;
  try f ()
  with e ->
    let trace = Printexc.get_backtrace () in
    flush stdout;
    eprintf "Error: exception %s\n%s\n%!"
      (Printexc.to_string e)
      trace;
    exit 1

let parse_and_dump ~src_file ~json_file parse_file dump_tree =
  match parse_file ~src_file ~json_file with
  | None ->
      flush stdout;
      eprintf "Cannot interpret file %s\n%!" json_file;
      exit 1
  | Some ast ->
      dump_tree ast

let run parse_file dump_tree =
  match Sys.argv with
  | [| _; src_file; json_file |] ->
      safe_run (fun () ->
        parse_and_dump ~src_file ~json_file parse_file dump_tree
      )
  | _ ->
      eprintf "\
Usage: %s SRC_FILE JSON_FILE

Parse the json output (JSON_FILE) of a json-sitter parser which parsed
source file SRC_FILE. Then dump a representation of the OCaml abstract syntax
tree.
%!"
        Sys.argv.(0);
      exit 1
