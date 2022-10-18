(*
   Ensure that the tree-sitter gives us a node in the CST for every node
   in the grammar. Patterns (regexps) and token() constructs have no name
   and tree-sitter will produce no node in the CST unless a name is
   somehow assigned. We use the alias() construct to assign names to grammar
   nodes that don't have one.

   See:
   - for patterns: https://github.com/tree-sitter/tree-sitter/issues/1151
   - for token(): https://github.com/tree-sitter/tree-sitter/issues/1156
*)

open Printf
open Tree_sitter_t

type token_node_name =
  | Literal of string
  | Name of string

let get_token_node_name (token_contents : rule_body) : token_node_name option =
  let rec get (x : rule_body) =
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
    | PREC (_prec, x) -> get x
    | PREC_DYNAMIC (_prec, x) -> get x
    | PREC_LEFT (_prec, x) -> get x
    | PREC_RIGHT (_prec, x) -> get x
    | ALIAS alias -> get alias.content
    | FIELD (_field_name, x) -> get x
  in
  get token_contents

let extract_alias_rules_from_body add_rule body =
  let rec extract (x : rule_body) =
    match x with
    | SYMBOL _
    | STRING _
    | BLANK -> x

    | PATTERN _
    | IMMEDIATE_TOKEN _
    | TOKEN _ as x ->
        let preferred_name = Type_name.name_ts_rule_body x in
        let name = add_rule preferred_name x in
        ALIAS {
          value = name;
          named = true;
          content = x;
          must_be_preserved = true;
        }

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
  | PATTERN _
  | IMMEDIATE_TOKEN _
  | TOKEN _ as x ->
      (* already at the root of a rule body, will have a name. *)
      x
  | x -> extract x

let extract_rules make_unique rules =
  let new_rules = Hashtbl.create 100 in
  let add_rule preferred_name rule_body =
    let name = make_unique preferred_name in
    printf "add_rule pref:%s -> %s\n" preferred_name name;
    Hashtbl.replace new_rules name rule_body;
    name
  in
  let rewritten_rules =
    List.map (fun (name, body) ->
      let body = extract_alias_rules_from_body add_rule body in
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
  let make_unique =
    let scope = Fresh.create_scope () in
    fun preferred_name -> Fresh.create_name scope preferred_name
  in
  (* Register the rule names. They should be unique already. *)
  List.iter (fun (name, _body) ->
    let unique_name = make_unique name in
    if unique_name <> name then
      failwith (
        sprintf "Grammar defines multiple rules with the same name: %s"
          name
      )
  ) rules;
  (* Then create new rules. Their preferred names are automatically
     derived and may collide. *)
  let new_rules = extract_rules make_unique rules in
  { grammar with rules = new_rules }
