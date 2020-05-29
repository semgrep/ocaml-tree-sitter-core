(*
   Conversion and simplification from type specified in Tree_sitter.atd.
*)

open AST_grammar

let name_of_body opt_rule_name body =
  match opt_rule_name with
  | Some rule_name -> Some rule_name
  | None ->
      match (body : Tree_sitter_t.rule_body) with
      | STRING cst -> Some cst
      | PATTERN pat -> Some pat
      | _ -> None

(*
   A constant string gets the name of the rule if applicable,
   otherwise its name is its value.

   grammar.js:

     percent: $ => '%'            // name is 'percent'
     percents: $ => repeat1('%')  // name of the repeated element is '%'
*)
let translate_constant opt_rule_name cst =
  let name =
    match opt_rule_name with
    | Some rule_name -> rule_name
    | None -> cst
  in
  Token {
    name;
    description = Constant cst
  }

(*
   We discard the rules describing how to parse a token since we don't
   need them.
*)
let translate_token opt_rule_name body =
  match name_of_body opt_rule_name body with
  | Some name -> Token { name; description = Token }
  | None -> Blank None

(*
   Unlike string constants, patterns without a name are omitted from
   tree-sitter's output.
*)
let translate_pattern opt_rule_name pat =
  match opt_rule_name with
  | Some name -> Token { name; description = Pattern pat }
  | None -> Blank None

(*
   Simple translation without normalization. Get rid of PREC_*

   find_alias takes a rule name and an alias name, and returns the
   globally-unique alias ID.

   The optional rule_name is the name given to this value, if there's one.
   e.g. in grammar.js:

     number: $ => /[0-9]+/

   For the above, we'd call:

     translate ~rule_name:"number" (PATTERN "[0-9]+")

   The parsing result would be a node with field type:"number" instead of
   type:"[0-9]+" in an anonymous context.
*)
let translate ~rule_name (x : Tree_sitter_t.rule_body) =
  let rec translate ?rule_name x =
    match (x : Tree_sitter_t.rule_body) with
    | SYMBOL ident -> Symbol ident
    | STRING cst -> translate_constant rule_name cst
    | PATTERN pat -> translate_pattern rule_name pat
    | IMMEDIATE_TOKEN body
    | TOKEN body -> translate_token rule_name body
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
    | ALIAS _alias -> failwith "aliases are not supported"
  in
  translate ~rule_name x

(*
   Algorithm: convert the nodes of tree from unnormalized to normalized,
   starting from the leaves. This ensures that the argument of flatten_choice
   or flatten_seq is already fully normalized.
*)
let rec normalize x =
  match x with
  | Symbol _
  | Token _
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
            Token { name; description = External }
        in
        Some (name, body)
    | Tree_sitter_t.STRING _ -> None (* no need for a rule *)
    | _ -> failwith "found member of 'externals' that's not a SYMBOL or STRING"
  ) externals

let translate_rules rules =
  List.map (fun (rule_name, body) ->
    let body = translate ~rule_name body |> normalize in
    (rule_name, body)
  ) rules

let tsort_rules rules =
  let sorted = Topo_sort.sort rules in
  List.map (fun group ->
    List.map (fun (is_rec, (name, body)) ->
      { name; is_rec; body }) group
  ) sorted

let filter_extras bodies =
  List.filter_map (fun (x : Tree_sitter_t.rule_body) ->
    match x with
    | SYMBOL name -> Some name
    | STRING name ->
        (* Results in tree-sitter parse error at the moment.
           Presumably not super useful. *)
        Some name
    | _ -> None
  ) bodies

let of_tree_sitter (x : Tree_sitter_t.grammar) : t =
  let entrypoint =
    (* assuming the grammar's entrypoint is the first rule in grammar.json *)
    match x.rules with
    | (name, _) :: _ -> name
    | _ -> "program"
  in
  let grammar_rules = translate_rules x.rules in
  let all_rules = make_external_rules x.externals @ grammar_rules in
  let sorted_rules = tsort_rules all_rules in
  let extras = filter_extras x.extras in
  {
    name = x.name;
    entrypoint;
    rules = sorted_rules;
    extras;
  }
