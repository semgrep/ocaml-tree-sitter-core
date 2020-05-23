(*
   Conversion and simplification from type specified in Tree_sitter.atd.
*)

open Printf
open AST_grammar

let translate_alias find_alias (alias : Tree_sitter_t.alias) =
  if alias.named then
    (match alias.content with
     | SYMBOL rule_name ->
         let alias_with_id : alias = find_alias rule_name alias.value in
         Symbol (rule_name, Some alias_with_id)
     | _ ->
         failwith
           (sprintf "Unexpected structure for ALIAS node %S" alias.value)
    )
  else
    (* This gets rid of the grammar rules used by the tree-sitter parser
       to parse such value. *)
    String alias.value

(*
   Simple translation without normalization. Get rid of PREC_*

   find_alias takes a rule name and an alias name, and returns the
   globally-unique alias ID.
*)
let translate find_alias (x : Tree_sitter_t.rule_body) =
  let rec translate x =
    match (x : Tree_sitter_t.rule_body) with
    | SYMBOL ident -> Symbol (ident, None)
    | STRING name -> String name
    | PATTERN pat -> Pattern pat
    | BLANK -> Blank None
    | REPEAT x -> Repeat (translate x)
    | REPEAT1 x -> Repeat1 (translate x)
    | CHOICE [x; BLANK] -> Optional (translate x)
    | CHOICE l -> Choice (List.map translate l)
    | SEQ l -> Seq (List.map translate l)
    | PREC (_prio, x) -> translate x
    | PREC_DYNAMIC (_prio, x) -> translate x
    | PREC_LEFT (_opt_prio, x) -> translate x
    | PREC_RIGHT (_opt_prio, x) -> translate x
    | FIELD (_name, x) -> translate x (* TODO not sure about ignoring this *)
    | ALIAS alias -> translate_alias find_alias alias
    | IMMEDIATE_TOKEN x -> translate x (* TODO check what this is *)
    | TOKEN x -> translate x
  in
  translate x

(*
   Algorithm: convert the nodes of tree from unnormalized to normalized,
   starting from the leaves. This ensures that the argument of flatten_choice
   or flatten_seq is already fully normalized.
*)
let rec normalize x =
  match x with
  | Symbol _
  | String _
  | Pattern _
  | Blank _ as x -> x
  | Repeat x -> Repeat (normalize x)
  | Repeat1 x -> Repeat1 (normalize x)
  | Choice l -> Choice (List.map normalize l |> flatten_choice)
  | Optional x -> Optional (normalize x)
  | Seq l -> Seq (List.map normalize l |> flatten_seq)

and flatten_choice normalized_list =
  normalized_list
  |> List.map (function
    | Choice l -> l
    | other -> [other]
  )
  |> List.flatten

and flatten_seq normalized_list =
  normalized_list
  |> List.map (function
    | Seq l -> l
    | other -> [other]
  )
  |> List.flatten

let make_external_rules externals =
  List.filter_map (function
    | Tree_sitter_t.SYMBOL name ->
        let body =
          if is_inline name then
            Blank (Some name)
          else
            String name
        in
        Some (name, body)
    | Tree_sitter_t.STRING _ -> None (* no need for a rule *)
    | _ -> failwith "found member of 'externals' that's not a SYMBOL or STRING"
  ) externals

let extract_aliases rules =
  let aliases = Alias.extract_named_aliases rules in
  let rules_tbl = Hashtbl.create 100 in
  let aliases_tbl = Hashtbl.create 100 in
  List.iter (fun (rule_name, rule_aliases) ->
    Hashtbl.add rules_tbl rule_name rule_aliases;
    List.iter (fun (alias : alias) ->
      Hashtbl.add aliases_tbl (rule_name, alias.name) alias
    ) rule_aliases;
  ) aliases;
  let find_rule_aliases rule_name =
    try Hashtbl.find rules_tbl rule_name
    with Not_found -> []
  in
  let find_alias rule_name alias_name =
    try Hashtbl.find aliases_tbl (rule_name, alias_name)
    with Not_found -> assert false
  in
  find_rule_aliases, find_alias

let translate_rules find_alias rules =
  List.map (fun (name, body) ->
    let body = translate find_alias body |> normalize in
    (name, body)
  ) rules

let tsort_rules find_rule_aliases rules =
  let sorted = Topo_sort.sort rules in
  List.map (fun group ->
    List.map (fun (is_rec, (name, body)) ->
      let aliases = find_rule_aliases name in
      { name; aliases; is_rec; body }) group
  ) sorted

let of_tree_sitter (x : Tree_sitter_t.grammar) : t =
  let entrypoint =
    (* assuming the grammar's entrypoint is the first rule in grammar.json *)
    match x.rules with
    | (name, _) :: _ -> name
    | _ -> "program"
  in
  let find_rule_aliases, find_alias = extract_aliases x.rules in
  let grammar_rules = translate_rules find_alias x.rules in
  let all_rules = make_external_rules x.externals @ grammar_rules in
  let sorted_rules = tsort_rules find_rule_aliases all_rules in
  {
    name = x.name;
    entrypoint;
    rules = sorted_rules;
  }
