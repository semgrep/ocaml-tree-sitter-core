(*
   Error message formatting.
*)

(*
   Fatal syntax error due to bad input or a bad grammar.

   The argument is a preformatted, multiline error message similar to
   the argument of a Failure exception. Doesn't benefit from showing
   a stack trace.
*)
exception External_error of string

(*
   Fatal error due to a bug in the code being executed.

   The argument is a preformatted, multiline error message similar to
   the argument of a Failure exception. Doesn't benefit from showing
   a stack trace.
*)
exception Internal_error of string

(*
   Fail, raising an External_error exception.
   The string argument is an arbitrary message to be printed as part of
   an error message.
*)
val external_error :
  Src_file.t ->
  Tree_sitter_bindings.Tree_sitter_output_t.node ->
  string -> 'a

(*
   Fail, raising an Internal_error exception.
   The string argument is an arbitrary message to be printed as part of
   an error message.
*)
val internal_error :
  Src_file.t ->
  Tree_sitter_bindings.Tree_sitter_output_t.node ->
  string -> 'a
