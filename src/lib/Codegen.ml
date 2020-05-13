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

let translate_ident =
  let registry = Protect_ident.create () in
  fun ident -> Protect_ident.translate registry ident

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
  | Symbol ident -> [`Line (translate_ident ident)]
  | String s -> [`Line (sprintf "string (* %S *)" s)]
  | Pattern s -> [`Line (sprintf "string (* pattern %S *)" s)]
  | Blank -> [`Line "string (* blank *)"]
  | Repeat body ->
      [
        `Inline (format_body body);
        `Block [`Line "list (* zero or more *)"]
      ]
  | Repeat1 body ->
      [
        `Inline (format_body body);
        `Block [`Line "list (* one or more *)"]
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
      `Line (sprintf "| `%s of (" name);
      `Block [`Block (format_body body)];
      `Line "  )"
    ]
  ) l

and format_seq l =
  List.map (fun body -> `Block (format_body body)) l
  |> interleave (`Line "*")

let format_rule ~use_rec pos (name, body) : Indent.t =
  let is_first = pos > 0 in
  let type_ =
    if use_rec && is_first then
      "and"
    else
      "type"
  in
  [
    `Line (sprintf "%s %s =" type_ (translate_ident name));
    `Block (format_body body);
  ]

let format grammar : Indent.t =
  let use_rec, rules =
    let orig_rules = grammar.rules in
    match Topo_sort.sort orig_rules with
    | Some reordered_rules -> false, reordered_rules
    | None -> true, orig_rules
  in
  List.mapi
    (fun pos x -> `Inline (format_rule ~use_rec pos x))
    rules
  |> interleave (`Line "")

let generate_ast_code grammar =
  let tree = format grammar in
  Indent.to_string tree

let save filename data =
  let oc = open_out filename in
  output_string oc data;
  close_out oc

let mkpath opt_dir filename =
  match opt_dir with
  | None -> filename
  | Some dir -> Filename.concat dir filename

let ocaml ?out_dir ?lang grammar =
  let lang_suffix =
    match lang with
    | None -> ""
    | Some s -> "_" ^ s
  in
  let ast_module = sprintf "AST%s" lang_suffix in
  let parse_module = sprintf "Parse%s" lang_suffix in
  let ast_file = mkpath out_dir (sprintf "%s.ml" ast_module) in
  let parse_file = mkpath out_dir (sprintf "%s.ml" parse_module) in

  let ast_code = generate_ast_code grammar in
  let parse_code = "TODO" in
  save ast_file ast_code;
  save parse_file parse_code
