(*
   Emit code.
*)

open Printf

(*
   Code is presented as a tree of lines and blocks, which is then
   printed with the correct indentation.

   This produces a lot of whitespace but it's easy to maintain,
   and the output and be passed through a dedicated reformatter such
   as refmt if needed.
*)
module Indent = struct
  type node = [
    | `Line of string
    | `Block of node list
    | `Inline of node list
  ]

  type t = node list

  let rec print_node buf indent (x : node) =
    match x with
    | `Line s -> bprintf buf "%s%s\n" (String.make indent ' ') s
    | `Block l -> print buf (indent + 2) l
    | `Inline l -> print buf indent l

  and print buf indent l =
    List.iter (print_node buf indent) l

  let to_string l =
    let buf = Buffer.create 1000 in
    print buf 0 l;
    Buffer.contents buf
end

open AST_grammar

let interleave sep l =
  let rec loop = function
    | [] -> []
    | x :: xs -> sep :: x :: loop xs
  in
  match l with
  | x :: xs -> x :: loop xs
  | [] -> []

let rec format_body body : Indent.t =
  match body with
  | Symbol ident -> [`Line ident]
  | String s -> [`Line (sprintf "string /* %S */" s)]
  | Pattern s -> [`Line (sprintf "string /* pattern %S */" s)]
  | Repeat body ->
      [
        `Line "list(";
        `Block (format_body body);
        `Line ")"
      ]
  | Choice body_list ->
      [
        `Line "[";
        `Inline (format_choice body_list);
        `Line "]"
      ]
  | Seq body_list ->
      [
        `Line "(";
        `Block (format_seq body_list);
        `Line ")"
      ]

and format_choice l =
  List.mapi (fun i body ->
    let name = sprintf "Case%i" i in
    `Inline [
      `Line (sprintf "| `%s(" name);
      `Block [`Block (format_body body)];
      `Line "  );"
    ]
  ) l

and format_seq l =
  List.map (fun body -> `Block (format_body body)) l
  |> interleave (`Line ",")

let format_rule ~use_rec pos (name, body) : Indent.t =
  let type_ =
    if use_rec && pos > 0 then
      "and"
    else
      "type"
  in
  [
    `Line (sprintf "%s %s =" type_ name);
    `Block (format_body body);
  ]

(* TODO *)
let tsort _rules = None

let format grammar : Indent.t =
  let use_rec, rules =
    let orig_rules = grammar.rules in
    match tsort orig_rules with
    | Some reordered_rules -> false, reordered_rules
    | None -> true, orig_rules
  in
  List.mapi (fun pos x -> `Inline (format_rule ~use_rec pos x)) rules
  |> interleave (`Line "")

let reason grammar =
  let tree = format grammar in
  Indent.to_string tree
