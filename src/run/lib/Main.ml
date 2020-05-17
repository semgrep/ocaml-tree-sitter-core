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
    eprintf "Error: exception %s\n%s\n%!"
      (Printexc.to_string e)
      trace;
    exit 1

let run parse_file dump_tree =
  match Sys.argv with
  | [| _; input_file |] ->
      safe_run (fun () ->
        parse_file input_file
        |> dump_tree
      )
  | _ ->
      eprintf "Usage: %s INPUT_FILE\n%!" Sys.argv.(0);
      exit 1
