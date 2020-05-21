(*
   Unit tests for the Fresh module.
*)

open Ocaml_tree_sitter_gen

let test_simple () =
  let scope = Fresh.create_scope () in
  let add name = Fresh.create_name scope name in
  assert (add "x" = "x");
  assert (add "y" = "y");
  assert (add "x" = "x_");
  assert (add "x" = "x1")

let test_prefix_prefix () =
  let scope = Fresh.create_scope () in
  let add name = Fresh.create_name scope name in
  assert (add "x" = "x");
  assert (add "x_" = "x_");
  assert (add "x" = "x1");
  assert (add "x_" = "x__");
  assert (add "x_" = "x_1")

let test = "Disambiguate", [
  "simple", `Quick, test_simple;
  "prefix of prefix", `Quick, test_prefix_prefix;
]
