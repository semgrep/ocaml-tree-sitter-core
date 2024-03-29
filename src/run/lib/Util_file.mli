(*
   Generic file utilities not provided by OCaml.
*)

(* you should set this flag when you run code compiled by js_of_ocaml *)
val jsoo : bool ref

(* Read the contents of file.

   This implementation works even with Linux files like /dev/fd/63
   created by bash when using "process substitution"* e.g.

     my-ocaml-program <(echo contents)

   * https://www.gnu.org/software/bash/manual/html_node/Process-Substitution.html
*)
val read_file : string -> string
