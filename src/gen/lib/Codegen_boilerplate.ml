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

let destruct x =
  match x with
  | Symbol _ -> ["x", x]
  | Token _ -> ["tok", x]
  | Blank -> []
  | Repeat _ -> ["xs", x]
  | Repeat1 _ -> ["xs", x]
  | Choice _ -> ["x", x]
  | Optional _ -> ["opt", x]
  | Seq l ->
      List.mapi (fun i x -> (sprintf "v%i" (i+1), x)) l

let mkpat env =
  match List.map fst env with
  | [] -> "()"
  | [var] -> var
  | l -> sprintf "(%s)" (String.concat ", " l)

let mkexp env = mkpat env

let rec gen_mapper_body var body : node list =
  match body with
  | Symbol name -> [ Line (sprintf "map_%s %s" (trans name) var) ]
  | Token _token -> [ Line (sprintf "token %s" var)]
  | Blank -> [ Line (sprintf "blank %s" var)]
  | Repeat (Symbol name)
  | Repeat1 (Symbol name) ->
      [ Line (sprintf "List.map map_%s %s" (trans name) var) ]
  | Repeat (Token _token)
  | Repeat1 (Token _token) ->
      [ Line (sprintf "List.map token %s" var) ]
  | Repeat body
  | Repeat1 body ->
      let env = destruct body in
      [
        Line (sprintf "List.map (fun %s ->" (mkpat env));
        Block (gen_mapper_body_multi env);
        Line (sprintf ") %s" var)
      ]
  | Choice l ->
      let cases =
        List.map (fun (name, body) ->
          let env = destruct body in
          Group [
            Line (sprintf "| `%s %s ->" name (mkpat env));
            Space;
            Block [Block (gen_mapper_body_multi env)]
          ]
        ) l
      in
      [
        Line (sprintf "(match %s with" var);
        Inline cases;
        Line ")";
      ]
  | Optional body ->
      let env = destruct body in
      [
        Line (sprintf "(match %s with" var);
        Group [
          Line (sprintf "| Some %s ->" (mkpat env));
          Space;
          Block [Block (gen_mapper_body_multi env)];
        ];
        Line (sprintf "| None -> todo ())")
      ]
  | Seq _ as body ->
      let env = destruct body in
      [
        Line (sprintf "let %s = %s in" (mkpat env) var);
        Inline (gen_mapper_body_multi env)
      ]

and gen_mapper_body_multi env =
  match env with
  | [] -> [ Line "todo ()" ]
  | [var, body] -> gen_mapper_body var body
  | env ->
      let bindings =
        List.map (fun (var, body) ->
          Group [
            Line (sprintf "let %s =" var);
            Space;
            Block (gen_mapper_body var body);
            Space;
            Line "in";
          ]
        ) env
      in
      [
        Inline bindings;
        Line (sprintf "todo %s" (mkexp env))
      ]

let gen_rule_mapper_binding ~cst_module_name (rule : rule) =
  let name = rule.name in
  let env = destruct rule.body in
  [
    Line (sprintf "map_%s (%s : %s.%s) ="
            (trans name) (mkpat env)
            cst_module_name (trans name));
    Block (gen_mapper_body_multi env);
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
