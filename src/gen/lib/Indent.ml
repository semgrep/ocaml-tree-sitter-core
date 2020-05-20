(*
   Simple, functional pretty-printer.
*)

open Printf

module Types = struct
  type node =
    | Line of string
    | Paren of string * node list * string
    | Block of node list
    | Inline of node list
end

open Types

type t = node list

(*
   Expand Inline and Paren nodes, remove empty blocks.
*)
let rec simplify l =
  List.map simplify_node l
  |> List.flatten

and simplify_node = function
  | Line _ as x -> [x]
  | Paren (open_, l, close) ->
      (match simplify l with
       | [Line s] -> [Line (open_ ^ s ^ close)]
       | [] -> [Line (open_ ^ close)]
       | l ->
           [
             Line open_;
             Block l;
             Line close;
           ]
      )
  | Block l ->
      (match simplify l with
       | [] -> []
       | l -> [Block l]
      )
  | Inline l ->
      (match simplify l with
       | [] -> []
       | l -> l
      )

let rec print_node buf indent (x : node) =
  match x with
  | Line s -> bprintf buf "%s%s\n" (String.make indent ' ') s
  | Block l -> print buf (indent + 2) l
  | Inline _ -> assert false (* removed by 'simplify' *)
  | Paren _ -> assert false (* removed by 'simplify' *)

and print buf indent l =
  List.iter (print_node buf indent) l

let to_string l =
  let buf = Buffer.create 1000 in
  print buf 0 (simplify l);
  Buffer.contents buf
