(*
   Entrypoint to run the unit tests from the command line.
*)

let test_suites : unit Alcotest.test list = [
  Fresh.test;
  Protect_ident.test;
  Factorize.test;
]

let main () = Alcotest.run "ocaml-tree-sitter.gen" test_suites

let () = main ()
