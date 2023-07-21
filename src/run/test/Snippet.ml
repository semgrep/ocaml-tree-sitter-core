(*
   Test the Snippet module.

   TODO: test the 'extract' function
*)

open Printf
open Tree_sitter_run

let check_format_with_color (lines, expected_res) =
  let res = Snippet.format ~color:true lines in
  printf "Highlighted result:\n%s" res;
  (* This is for copy-pasting the expected string into the OCaml test: *)
  printf "Same, OCaml-escaped: %S\n" res;
  printf "           Expected: %S\n" expected_res;
  Alcotest.(check string) "equal" expected_res res

let check_format_without_color (lines, expected_res) =
  let res = Snippet.format ~color:false lines in
  printf "Highlighted result:\n%s" res;
  (* This is for copy-pasting the expected string into the OCaml test: *)
  printf "Same, OCaml-escaped: %S\n" res;
  printf "           Expected: %S\n" expected_res;
  Alcotest.(check string) "equal" expected_res res

let test_format_with_color () =
  (* The expected output is meant to be copy pasted from the test output. *)
  let data : (Snippet.t * string) list = [
    [
      [Normal "A"; Highlight "H"; Normal "B" ]
    ], "A\027[1;4;31mH\027[0mB\n";
    [
      [Normal "A"];
      [Normal "B"; Highlight "H"; Normal "C" ];
      [Normal "D"];
    ], "A\nB\027[1;4;31mH\027[0mC\nD\n";
    [
      [Normal "A\n"];
      [Highlight "H\n"];
      [Normal "B\n"];
    ], "A\n\027[1;4;31mH\n\027[0mB\n";
    (* Special case of highlighting a newline.
       Note that highlighting empty regions is handled by the 'extract'
       function by creating nonempty Highlight fragments for one character. *)
    [
      [Normal "highlight newline:"; Highlight "\n"];
      [Normal "N"]
    ], "highlight newline:\027[1;4;31m \n\027[0mN\n";
  ] in
  data
  |> List.iter check_format_with_color

let test_format_without_color () =
  (* The expected output is meant to be copy pasted from the test output. *)
  let data : (Snippet.t * string) list = [
    [
      [Normal "A"; Highlight "H"; Normal "B" ]
    ], "AHB\n ^ \n";
    [
      [Normal "A"];
      [Normal "B"; Highlight "H"; Normal "C" ];
      [Normal "D"];
    ], "A\nBHC\n ^ \nD\n";
    [
      [Normal "A\n"];
      [Highlight "H\n"];
      [Normal "B\n"];
    ], "A\nH\n^\nB\n";
    [
      [Normal "highlight newline:"; Highlight "\n"];
      [Normal "N"]
    ], "highlight newline: \n                  ^\nN\n";
  ] in
  data
  |> List.iter check_format_without_color

let test = "Snippet", [
  "highlight snippet with color", `Quick, test_format_with_color;
  "highlight snippet without color", `Quick, test_format_without_color;
]
