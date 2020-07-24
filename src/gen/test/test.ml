(*
   All the unit tests for this library.
*)

let test_suites : unit Alcotest.test list = [
  Fresh.test;
  Protect_ident.test;
  Factorize.test;
]
