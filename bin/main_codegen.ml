(*
 * The author disclaims copyright to this source code.  In place of
 * a legal notice, here is a blessing:
 *
 *    May you do good and not evil.
 *    May you find forgiveness for yourself and forgive others.
 *    May you share freely, never taking more than you give.
 *)

open Common

(* Purpose

   Generating OCaml code to type the Concrete Syntax Trees (CSTs) produced
   by tree-sitter.
*)

(* Flags *)
let verbose = ref false
let debug = ref false
let version = "0.1"

(* action mode *)
let action = ref ""

let main_action _ = raise Todo

let all_actions () = [] @ (Test_tree_sitter.actions ())

let options () =
  List.flatten [
    ["-verbose", Arg.Unit (fun () -> verbose := true), " ";

     "-debug", Arg.Set debug,
     " add debugging information in the output (e.g., tracing)"
    ];
    Common.options_of_actions action (all_actions ());
    Common2.cmdline_flags_devel ();
    ["-version",
     Arg.Unit
       (fun () ->
          pr2 (spf "reason-tree-sitter version: %s" version);
          exit 0),
     " print version and exit."
    ]
  ]

let main () =
  let usage_msg =
    spf "\
Usage: %s [options]
Options:"
      (Filename.basename Sys.argv.(0))
  in
  let args = Common.parse_options (options ()) usage_msg Sys.argv in
  Common.profile_code "Main total" (fun () ->
    match args with
    | xs when List.mem !action (Common.action_list (all_actions ())) ->
        Common.do_action !action xs (all_actions ())
    | _ when not (Common.null_string (!action)) ->
        failwith ("unrecognized action or wrong params: " ^ !action)
    | x::xs ->
        main_action (x :: xs)
    | [] ->
        Common.usage usage_msg (options ())
  )

let () = Common.main_boilerplate (fun () -> main ())
