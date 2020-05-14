(*
   Simple, functional pretty-printer.

   Code is presented as a tree of lines and blocks, which is then
   printed with the correct indentation.

   This produces a lot of whitespace but it's easy to maintain,
   and the output and be passed through a dedicated reformatter such
   as refmt if needed.

   Usage:

   open Indent.Types
   ...

   let fmt_binding x =
     [
       Line "let x =";
       Block (fmt_body ...);
     ]

   ...

   let formatted_code = Indent.to_string (fmt_bindings ...)
*)

open Printf

module Types = struct
  type node =
    | Line of string
    | Block of node list
    | Inline of node list
end

open Types

type t = node list

let rec print_node buf indent (x : node) =
  match x with
  | Line s -> bprintf buf "%s%s\n" (String.make indent ' ') s
  | Block l -> print buf (indent + 2) l
  | Inline l -> print buf indent l

and print buf indent l =
  List.iter (print_node buf indent) l

let to_string l =
  let buf = Buffer.create 1000 in
  print buf 0 l;
  Buffer.contents buf
