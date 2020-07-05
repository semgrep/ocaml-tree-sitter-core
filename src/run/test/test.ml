(*
   Entrypoint to run the unit tests from the command line.
*)

let test_suites : unit Alcotest.test list = [
  Combine.test;
  Matcher.test;
]

let main () = Alcotest.run "ocaml-tree-sitter.run" test_suites

let () = main ()
