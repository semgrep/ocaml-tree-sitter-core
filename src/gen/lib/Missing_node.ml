(*
   Ensure that every pattern is at the root of a rule.
   This a workaround for the fact that tree-sitter parsers don't produce
   nodes matching patterns.
   See:
   - for patterns: https://github.com/tree-sitter/tree-sitter/issues/1151
   - for token(): https://github.com/tree-sitter/tree-sitter/issues/1156
*)

open Printf
open Tree_sitter_t

type token_node_name =
  | Literal of string
  | Name of string

let make_translator () =
  let map = Protect_ident.create () in
  fun ~orig_name ~preferred_name ->
    Protect_ident.add_translation ~preferred_dst:preferred_name map orig_name

(*
   Will token(...) produce a node? If so, we don't need to extract it
   and make it a separate rule.
*)
let token_produces_node (token_contents : rule_body) : token_node_name option =
  let rec is_simple (x : rule_body) =
    match x with
    | SYMBOL name -> Some (Name name)
    | STRING name -> Some (Literal name)
    | BLANK -> None
    | PATTERN _ -> None

    | IMMEDIATE_TOKEN _ -> None
    | TOKEN _ -> None
    | REPEAT _ -> None
    | REPEAT1 _ -> None
    | CHOICE _ -> None
    | SEQ _ -> None
    | PREC (_prec, x) -> is_simple x
    | PREC_DYNAMIC (_prec, x) -> is_simple x
    | PREC_LEFT (_prec, x) -> is_simple x
    | PREC_RIGHT (_prec, x) -> is_simple x
    | ALIAS alias -> is_simple alias.content
    | FIELD (_field_name, x) -> is_simple x
  in
  is_simple token_contents

let should_extract_token token_contents =
  let rec contains_prec (x : rule_body) =
    match x with
    | SYMBOL _
    | STRING _
    | BLANK
    | PATTERN _ -> false

    | IMMEDIATE_TOKEN x -> contains_prec x
    | TOKEN x -> contains_prec x
    | REPEAT x -> contains_prec x
    | REPEAT1 x -> contains_prec x
    | CHOICE xs -> List.exists contains_prec xs
    | SEQ xs -> List.exists contains_prec xs
    | PREC (_prec, _) -> true
    | PREC_DYNAMIC (_prec, _) -> true
    | PREC_LEFT (_prec, _) -> true
    | PREC_RIGHT (_prec, _) -> true
    | ALIAS alias -> contains_prec alias.content
    | FIELD (_field_name, x) -> contains_prec x
  in
  token_produces_node token_contents = None
  && not (contains_prec token_contents)

let extract_pattern_rules_from_body add_rule body =
  let rec extract (x : rule_body) =
    match x with
    | SYMBOL _
    | STRING _
    | BLANK -> x

    | PATTERN _ as x ->
        let preferred_name = Type_name.name_ts_rule_body x in
        let name = add_rule preferred_name x in
        (*
           Hack to make the node appear in the CST due to bug
           https://github.com/tree-sitter/tree-sitter/issues/1156
           This allows keeping the rule inline, which is important to preserve
           parsing behavior in some instances as was observed on the
           PHP grammar:
           https://github.com/returntocorp/ocaml-tree-sitter-core/issues/34
           [simpler example needed]
        *)
        ALIAS {
          value = name;
          named = true;
          content = x;
          must_be_preserved = true;
        }

    | IMMEDIATE_TOKEN _
    | TOKEN _ as x ->
        (* SYMBOLs (rule names like $.pat_123) are illegal within token()
           (https://github.com/tree-sitter/tree-sitter/issues/1159),
           so we leave any pattern that may be in there. It doesn't matter
           since the point of token() is to get a single token.
        *)
        x

    | REPEAT x -> REPEAT (extract x)
    | REPEAT1 x -> REPEAT1 (extract x)
    | CHOICE xs -> CHOICE (List.map extract xs)
    | SEQ xs -> SEQ (List.map extract xs)
    | PREC (prec, x) -> PREC (prec, extract x)
    | PREC_DYNAMIC (prec, x) -> PREC_DYNAMIC (prec, extract x)
    | PREC_LEFT (prec, x) -> PREC_LEFT (prec, extract x)
    | PREC_RIGHT (prec, x) -> PREC_RIGHT (prec, extract x)
    | ALIAS alias -> ALIAS { alias with content = extract alias.content }
    | FIELD (field_name, x) -> FIELD (field_name, extract x)
  in
  match body with
  | PATTERN _pat as x ->
      (* already at the root of a rule body, will have a name. *)
      x
  | x -> extract x

let extract_token_rules_from_body add_rule body =
  let rec extract (x : rule_body) =
    match x with
    | SYMBOL _
    | STRING _
    | BLANK -> x
    | PATTERN _ as x -> x

    | IMMEDIATE_TOKEN token_contents
    | TOKEN token_contents as x ->
        if should_extract_token token_contents then
          let preferred_name = Type_name.name_ts_rule_body x in
          let name = add_rule preferred_name x in
          SYMBOL name
        else
          (* ok, we keep it. It will produce a node or it won't. We'll need
             to re-analyze this when generating the code that consumes
             the tree. *)
          x

    | REPEAT x -> REPEAT (extract x)
    | REPEAT1 x -> REPEAT1 (extract x)
    | CHOICE xs -> CHOICE (List.map extract xs)
    | SEQ xs -> SEQ (List.map extract xs)
    | PREC (prec, x) -> PREC (prec, extract x)
    | PREC_DYNAMIC (prec, x) -> PREC_DYNAMIC (prec, extract x)
    | PREC_LEFT (prec, x) -> PREC_LEFT (prec, extract x)
    | PREC_RIGHT (prec, x) -> PREC_RIGHT (prec, extract x)
    | ALIAS alias -> ALIAS { alias with content = extract alias.content }
    | FIELD (field_name, x) -> FIELD (field_name, extract x)
  in
  match body with
  | IMMEDIATE_TOKEN _
  | TOKEN _ as x ->
      (* already at the root of a rule body, will have a name. *)
      x
  | x -> extract x

let extract_rules add_translation rules =
  let new_rules = Hashtbl.create 100 in
  let add_rule preferred_name rule_body =
    let name =
      add_translation ~orig_name:preferred_name ~preferred_name
    in
    Hashtbl.replace new_rules name rule_body;
    name
  in
  let rewritten_rules =
    List.map (fun (name, body) ->
      let body = extract_pattern_rules_from_body add_rule body in
      let body = extract_token_rules_from_body add_rule body in
      (name, body)
    ) rules
  in
  let new_rules =
    Hashtbl.fold (fun name body acc -> (name, body) :: acc) new_rules []
    |> List.sort (fun (a, _) (b, _) -> String.compare a b)
  in
  rewritten_rules @ new_rules

(*
   Create rules for constructs that are known to produce a missing node.
*)
let work_around_missing_nodes grammar =
  let rules = grammar.rules in
  let add_translation = make_translator () in
  (* Register the rule names. They should be unique already. *)
  List.iter (fun (name, _body) ->
    let translated =
      add_translation ~orig_name:name ~preferred_name:name
    in
    if translated <> name then
      failwith (
        sprintf "Grammar defines multiple rules with the same name: %s"
          name
      )
  ) rules;
  let new_rules = extract_rules add_translation rules in
  { grammar with rules = new_rules }
