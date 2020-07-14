(*
   Unit tests for the Protect_ident module.
*)

open Printf
open Tree_sitter_gen

let test_translate () =
  let reserved = ["foo"; "bar_"] in
  let translations = [
    "thing", "thing";
    "foo", "foo_";
    "bar_", "bar__";
    "bar", "bar";
  ] in
  let registry = Protect_ident.create ~reserved in
  List.iter (fun (src, expected_dst) ->
    let dst = Protect_ident.translate registry src in
    printf "%s -> %s\n%!" src dst;
    Alcotest.(check string) "match" expected_dst dst
  ) translations

let test_reserve () =
  let reserved = [] in
  let preferred_translations = [
    ("foo", "foo"), "foo";
    ("_foo", "foo"), "foo_";
    ("__foo", "foo"), "foo2";
    ("_foo", "foo"), "foo_";
  ] in
  let registry = Protect_ident.create ~reserved in
  List.iter (fun ((src, preferred_dst), expected_dst) ->
    let dst = Protect_ident.reserve registry ~src ~preferred_dst in
    printf "%s -> %s\n%!" src dst;
    Alcotest.(check string) "match" expected_dst dst
  ) preferred_translations

let test = "Protect_ident", [
  "translate", `Quick, test_translate;
  "reserve", `Quick, test_reserve;
]
