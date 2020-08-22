(*
   Add grammar rules to ensure that no pattern remains anonymous.
*)

open Printf
open Tree_sitter_t

let make_translator () =
  let map = Protect_ident.create () in
  fun ~orig_name ~preferred_name ->
    Protect_ident.add_translation ~preferred_dst:preferred_name map orig_name

let extract_pattern_rules_from_body add_rule body =
  let rec extract x =
    match x with
    | SYMBOL _
    | STRING _
    | BLANK -> x
    | PATTERN _ as x ->
        let preferred_name = Type_name.name_ts_rule_body x in
        let name = add_rule preferred_name x in
        SYMBOL name
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
    | IMMEDIATE_TOKEN _ as x ->
        let preferred_name = Type_name.name_ts_rule_body x in
        let name = add_rule preferred_name x in
        SYMBOL name
    | TOKEN _ as x ->
        let preferred_name = Type_name.name_ts_rule_body x in
        let name = add_rule preferred_name x in
        SYMBOL name
  in
  match body with
  | PATTERN _ as x -> x (* already at the root of a rule body *)
  | x -> extract x

let extract_pattern_rules add_translation rules =
  let pattern_rules = Hashtbl.create 100 in
  let add_rule preferred_name rule_body =
    let name =
      add_translation ~orig_name:preferred_name ~preferred_name
    in
    Hashtbl.replace pattern_rules name rule_body;
    name
  in
  let rewritten_rules =
    List.map (fun (name, body) ->
      let body = extract_pattern_rules_from_body add_rule body in
      (name, body)
    ) rules
  in
  let new_rules =
    Hashtbl.fold (fun name body acc -> (name, body) :: acc) pattern_rules []
    |> List.sort (fun (a, _) (b, _) -> String.compare a b)
  in
  rewritten_rules @ new_rules

let assign_names_to_patterns grammar =
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
  let new_rules = extract_pattern_rules add_translation rules in
  { grammar with rules = new_rules }
