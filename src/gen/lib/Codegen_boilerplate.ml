(*
   Derive boilerplate to be used as a template when mapping a CST
   to another type of tree.
*)

open Printf
open CST_grammar
open Indent.Types

let trans = Codegen_util.translate_ident

let make_header grammar = sprintf
{|(**
   Boilerplate to be used as a template when mapping the %s CST
   to another type of tree.
*)

(* Disable warnings against unused variables *)
[@@@warning "-26-27"]

(* Disable warning against unused 'rec' *)
[@@@warning "-39"]

let token (_tok : Tree_sitter_run.Token.t) = failwith "not implemented"
let blank () = failwith "not implemented"
let todo _ = failwith "not implemented"

|}
    grammar.name

let todo = [ Line "todo ()" ]

let simple_pat = function
  | Symbol _ -> "x"
  | Token _ -> "tok"
  | Blank -> "()"
  | Repeat _ -> "xs"
  | Repeat1 _ -> "xs"
  | Choice _ -> "x"
  | Optional _ -> "opt"
  | Seq l ->
      sprintf "(%s)"
        (List.mapi (fun i _ -> sprintf "v%i" (i+1)) l
         |> String.concat ", ")

let simple_exp x = simple_pat x

let gen_rule_mapper_body body =
  let arg = simple_exp body in
  match body with
  | Symbol name -> [ Line (sprintf "map_%s %s" (trans name) arg) ]
  | Token _token -> [ Line (sprintf "token %s" arg)]
  | Blank -> [ Line (sprintf "blank %s" arg)]
  | Repeat (Symbol name)
  | Repeat1 (Symbol name) ->
      [ Line (sprintf "List.map map_%s %s" (trans name) arg) ]
  | Repeat (Token _token)
  | Repeat1 (Token _token) ->
      [ Line (sprintf "List.map token %s" arg) ]
  | Repeat x
  | Repeat1 x ->
      [
        Line (
          sprintf "List.map (fun %s -> todo %s) %s"
            (simple_pat x) (simple_exp x) arg
        )
      ]
  | Choice l ->
      let cases =
        List.map (fun (name, body) ->
          Line (sprintf "| `%s %s -> todo %s"
                  name (simple_pat body) (simple_exp body))
        ) l
      in
      [
        Line (sprintf "match %s with" arg);
        Inline cases;
      ]
  | Optional body ->
      [
        Line (sprintf "match %s with" arg);
        Line (sprintf "| Some %s -> todo %s"
                (simple_pat body) (simple_exp body));
        Line (sprintf "| None -> todo ()")
      ]
  | Seq _ ->
      [ Line (sprintf "todo %s" arg) ]

let gen_rule_mapper_binding ~cst_module_name (rule : rule) =
  let name = rule.name in
  [
    Line (sprintf "map_%s (%s : %s.%s) ="
            (trans name) (simple_pat rule.body)
            cst_module_name (trans name));
    Block (gen_rule_mapper_body rule.body);
    Line "";
  ]

let gen ~cst_module_name grammar =
  List.map (fun rule_group ->
    let is_rec =
      match rule_group with
      | [x] -> x.is_rec
      | _ -> true
    in
    let rule_mappers =
      let bindings =
        List.filter_map (fun rule ->
          if rule.is_inlined then
            None
          else
            Some (gen_rule_mapper_binding ~cst_module_name rule)
        ) rule_group
      in
      Codegen_util.format_bindings ~is_rec ~is_local:false bindings
    in
    rule_mappers
  ) grammar.rules
  |> List.flatten

let generate ~cst_module_name grammar =
  let inline_grammar = Inline.inline_rules grammar in
  let tree = gen ~cst_module_name inline_grammar in
  make_header grammar ^ Indent.to_string tree
