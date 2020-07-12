(*
   Test the regular expression matchers.
*)

open Printf
open Tree_sitter_run

module String_token = struct
  type kind = string
  type t = string
  let kind s = s
  let show_kind s = s
  let show s = s
end

let a = "a"
let b = "b"

let show_tokens tokens =
  String.concat " " tokens

let test
    match_tree
    (exp : string Matcher.exp)
    (tokens : string list)
    (expected_output : string Matcher.capture option) =
  let output = match_tree exp tokens in
  printf "input:\n  %s\n%!" (show_tokens tokens);
  printf "expected output:\n  %s\n%!"
    (Matcher.show_match String_token.show expected_output);
  printf "output:\n  %s\n%!"
    (Matcher.show_match String_token.show output);
  if output <> expected_output then
    printf "FAIL\n"
  else
    printf "OK\n"

(*module Possessive = Possessive_matcher.Make (String_token)*)
module Backtrack = Backtrack_matcher.Make (String_token)

let test_b exp tokens expected_output =
  test Backtrack.match_tree exp tokens expected_output

(* Tests that don't need backtracking. *)

(* a *)
let test_token () =
  test_b
    (Token a)
    [a]
    (Some (Token a))

(* ab *)
let test_seq () =
  test_b
    (Seq [Token a; Token b])
    [a; b]
    (Some (Seq [Token a; Token b]))

(* a* *)
let test_repeat () =
  test_b
    (Repeat (Token a))
    [a;a]
    (Some (Repeat [Token a; Token a]))

(* (a|b) *)
let test_alt0 () =
  test_b
    (Alt [| Token a; Token b |])
    [a]
    (Some (Repeat [Token a]))

(* (a|b) *)
let test_alt1 () =
  test_b
    (Alt [| Token a; Token b |])
    [b]
    (Some (Repeat [Token a]))

(* ((a)?)? *)
let test_opt_alt_opt () =
  test_b
    (Opt (Alt [| Opt (Token a) |]))
    [a]
    (Some (Alt (0, Opt (Some (Token a)))))

(* Backtracking needed. *)

(* a*a *)
let test_backtrack () =
  test_b
    (Seq [Repeat (Token a); Token a])
    [a;a]
    (Some (Seq [Repeat [Token a]; Token a]))

(* a?a *)
let test_backtrack_opt () =
  test_b
    (Seq [Opt (Token a); Token a])
    [a]
    (Some (Seq [Opt None; Token a]))

(* More backtracking needed. *)

(* (a*a)*a *)
let test_much_backtrack () =
  test_b
    (
      Seq [
        Repeat (
          Seq [
            Repeat (Token a);
            Token a
          ]
        );
        Token a
      ]
    )
    [a;a]
    (
      Some (
        Seq [
          Repeat [
            Seq [
              Repeat [];
              Token a
            ]
          ];
          Token a
        ]
      )
    )

let test = "Matcher", [
  "token", `Quick, test_token;
  "seq", `Quick, test_seq;
  "repeat", `Quick, test_repeat;
  "alt0", `Quick, test_alt0;
  "alt1", `Quick, test_alt1;
  "backtrack", `Quick, test_backtrack;
  "backtrack opt", `Quick, test_backtrack_opt;
  "much backtrack", `Quick, test_much_backtrack;
  "opt(alt(opt()))", `Quick, test_opt_alt_opt;
]
