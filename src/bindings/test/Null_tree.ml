(*
   Regression test for NULL tree dereference.

   ts_parser_parse_string returns NULL when:
   1. No language is set on the parser (e.g. ABI version mismatch
      causes ts_parser_set_language to return false, unchecked by
      the generated code).
   2. Parsing was cancelled via timeout or cancellation flag.

   The binding in octs_parser_parse_string must detect NULL and
   raise an exception rather than wrapping it in a custom block
   that will segfault on the next tree operation.
*)

open Tree_sitter_bindings.Tree_sitter_API

(* C stubs -- see null_tree_stubs.c *)
external create_parser_no_language :
  unit -> ts_parser = "octs_test_create_parser_no_language"

(* parse_string on a languageless parser must raise, not return
   a wrapper around NULL. *)
let test_parse_string_raises_on_null () =
  let parser = create_parser_no_language () in
  match Parser.parse_string parser "int x = 1;" with
  | exception Failure _ -> ()
  | _ ->
      Alcotest.fail
        "parse_string should raise Failure when tree-sitter returns NULL"

let test = "Null tree", [
  "parse_string raises on NULL return",
  `Quick, test_parse_string_raises_on_null;
]
