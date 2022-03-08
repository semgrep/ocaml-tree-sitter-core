(*
   Convert a JSON grammar to JavaScript for better readability when
   debugging.
*)

(* Usage: run (Some "grammar.json") (Some "grammar.js") *)
val run : string option -> string option -> unit
