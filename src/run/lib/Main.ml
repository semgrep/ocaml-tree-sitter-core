(*
   Entrypoint for a standalone parser-dumper, to be called by generated
   parsers.
*)

open Printf

(*
   Different classes of errors, useful for parsing stats.
*)
module Exit = struct
  let any_error = 1
  let bad_command_line = 10
  let external_parsing_error = 11
  let internal_parsing_error = 12
end

let use_color () =
  !ANSITerminal.isatty Unix.stderr

let safe_run f =
  Printexc.record_backtrace true;
  try f ()
  with e ->
    let trace = Printexc.get_backtrace () in
    flush stdout;
    let msg, exit_code, show_trace =
      match e with
      | Tree_sitter_error.Error err ->
          let msg = Tree_sitter_error.to_string ~color:(use_color ()) err in
          let exit_code =
            match err.kind with
            | External -> Exit.external_parsing_error
            | Internal -> Exit.internal_parsing_error
          in
          msg,exit_code, false
      | Failure msg ->
          msg, Exit.any_error, true
      | e ->
          let msg = sprintf "exception %s" (Printexc.to_string e) in
          msg, Exit.any_error, true
    in
    (if show_trace then
       eprintf "Error: %s\n%s\n"
         msg
         trace
     else
       eprintf "Error: %s\n" msg
    );
    eprintf "\nexit %i\n" exit_code;
    flush stderr;
    exit exit_code

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
  Tree_sitter_parsing.print input_tree;
  parse_input_tree input_tree
  |> dump_tree

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
        exit Exit.bad_command_line
  in
  safe_run (fun () ->
    parse_and_dump
      ~parse_source_file
      ~src_file
      ~parse_input_tree
      ~dump_tree
      input_kind
  )
