(*
   All the unit tests for this library.
*)

let test_suites : unit Alcotest.test list = [
  Util_string.test;
  Matcher.test;
]
