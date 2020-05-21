(*
   Manage unique names for aliases.

   An alias is a local name used instead of the global rule name.
   Here we convert aliases to globally-unique names.

   This is a helper module for converting the original tree-sitter grammar
   into our normalized grammar.
*)

open Printf
open Tree_sitter_t

let extract_rule_names rules =
  List.map (fun (name, _) -> name) rules

let simplify_named_alias alias =
  assert (alias.named);
  match alias.content with
  | SYMBOL rule_name -> (rule_name, alias.value)
  | _ ->
      failwith
        (sprintf "Unexpected value found for 'content' field of ALIAS %s"
           alias.value)

let group_by_rule aliases =
  let pairs = List.map simplify_named_alias aliases in
  Util_list.group_by_key pairs
  |> List.map (fun (rule_name, aliases) ->
    (rule_name, Util_list.deduplicate aliases)
  )

let extract_named_aliases_from_rule acc (_rule_name, rule_body) =
  let rec extract acc rule_body =
    match rule_body with
    | SYMBOL _
    | STRING _
    | PATTERN _
    | BLANK -> acc
    | REPEAT rule_body
    | REPEAT1 rule_body -> extract acc rule_body
    | CHOICE rule_bodies
    | SEQ rule_bodies -> List.fold_left extract acc rule_bodies
    | PREC (_, rule_body)
    | PREC_DYNAMIC (_, rule_body)
    | PREC_LEFT (_, rule_body)
    | PREC_RIGHT (_, rule_body) -> extract acc rule_body
    | ALIAS { named = false; _ } -> acc
    | ALIAS ({ named = true; _ } as alias) ->
        let acc = alias :: acc in
        extract acc alias.content

    | FIELD (_ident, rule_body) -> extract acc rule_body
    | IMMEDIATE_TOKEN rule_body
    | TOKEN rule_body -> extract acc rule_body
  in
  extract acc rule_body

(* Extract and deduplicate named aliases from the grammar. *)
let extract_named_aliases rules =
  let rule_names = extract_rule_names rules in
  let scope =
    match Fresh.init_scope rule_names with
    | Ok scope -> scope
    | Error duplicates ->
        failwith (
          sprintf "Found duplicate rule names: %s"
            (String.concat ", " duplicates)
        )
  in
  let aliases =
    List.fold_left extract_named_aliases_from_rule [] rules in
  let grouped = group_by_rule aliases in
  List.map (fun (rule_name, aliases) ->
    let aliases_with_id =
      List.map (fun alias ->
        let id = Fresh.create_name scope alias in
        { AST_grammar.id; name = alias }
      ) aliases
    in
    (rule_name, aliases_with_id)
  ) grouped
