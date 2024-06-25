(*
   Convert a JSON grammar to JavaScript for better readability when
   debugging.
*)

(* Usage: run (Some "grammar.json") (Some "grammar.js")

   sort_rules: sort all the rule definitions alphabetically except for the
   first one because it must stay in place to be identified by tree-sitter
   as the grammar's entry point.
*)
val run : sort_rules:bool -> string option -> string option -> unit
