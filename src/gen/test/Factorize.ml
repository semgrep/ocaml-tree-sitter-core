(*
   Unit tests for the Factorize module.
*)

open Tree_sitter_gen
open CST_grammar

let make_grammar flat_rules =
  let rules = CST_grammar_conv.tsort_rules flat_rules in
  {
    name = "test";
    entrypoint = "program";
    rules;
    extras = [];
  }

let literal name =
  Token {
    name = name;
    is_inlined = false;
    description = Constant name;
  }

let factorize rules =
  let grammar = make_grammar rules in
  print_endline (CST_grammar.show_grammar grammar);
  grammar.rules

let flatten rule_groups =
  List.flatten rule_groups
  |> List.map (fun (rule : rule) -> (rule.name, rule.body))

let sort (rules : (string * rule_body) list) = List.sort compare rules

let test_simple () =
  let rule = "program", literal "thing" in
  assert (
    factorize [rule] |> flatten
    = [rule]
  )

let test_recursive () =
  let rule = "program", Symbol "program" in
  assert (
    factorize [rule] |> flatten
    = [rule]
  )

let test_no_sharing () =
  let rule1 = "rule1", literal "thing1" in
  let rule2 = "rule2", literal "thing2" in
  assert (
    ([rule1; rule2] |> factorize |> flatten |> sort)
    = sort [rule1; rule2]
  )

let test = "Factorize", [
  "simple", `Quick, test_simple;
  "recursive", `Quick, test_recursive;
  "no sharing", `Quick, test_no_sharing;
]
