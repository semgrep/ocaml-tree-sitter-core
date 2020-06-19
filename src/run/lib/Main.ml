(*
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
    let msg =
      match e with
      | Failure msg -> msg
      | e -> sprintf "exception %s" (Printexc.to_string e)
    in
    eprintf "Error: %s\n%s\n%!"
      msg
      trace;
    exit 1

type input_kind =
  | Source_file
  | Json_file of string

(*
   Obtain tree-sitter's CST either by parsing the source code
   or loading it from a json file.
*)
let load_input_tree ~parse_source_file ~src_file input_kind =
  match input_kind with
  | Source_file ->
      parse_source_file src_file
  | Json_file json_file ->
      Tree_sitter_parsing.load_json_file ~src_file ~json_file

let parse_and_dump
    ~parse_source_file
    ~src_file
    ~parse_input_tree
    ~dump_tree
    input_kind =
  let input_tree = load_input_tree ~parse_source_file ~src_file input_kind in
  match parse_input_tree input_tree with
  | None ->
      flush stdout;
      eprintf "Cannot interpret json file derived from %s.\n%!" src_file;
      exit 1
  | Some ast ->
      dump_tree ast

let usage ~lang () =
  eprintf "\
Usage: %s SRC_FILE [JSON_FILE]

Parse a %s file SRC_FILE and dump the resulting CST in a human-readable
format for inspection purposes. If provided, a json dump of the tree-sitter's
parse tree is loaded from JSON_FILE instead of the source file being
parsed from scratch.
%!"
    Sys.argv.(0) lang

let run ~lang ~parse_source_file ~parse_input_tree ~dump_tree =
  let usage () = usage ~lang () in
  let src_file, input_kind =
    match Sys.argv with
    | [| _; "--help" |] ->
        usage ();
        exit 0
    | [| _; src_file |] -> src_file, Source_file
    | [| _; src_file; json_file |] -> src_file, Json_file json_file
    | _ ->
        usage ();
        exit 1
  in
  safe_run (fun () ->
    parse_and_dump
      ~parse_source_file
      ~src_file
      ~parse_input_tree
      ~dump_tree
      input_kind
  )
