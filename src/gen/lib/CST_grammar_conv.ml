(*
   Conversion and simplification from type specified in Tree_sitter.atd.
*)

open Printf
open CST_grammar

(*
   Traverse the grammar starting from the entrypoint, return the set of
   visited rule names.
*)
let detect_used ~entrypoint rules =
  let rule_tbl = Hashtbl.create 100 in
  List.iter (fun (name, x) -> Hashtbl.add rule_tbl name x) rules;
  let get_rule name =
    (* could be an external rule (from the 'externals' field), which
       doesn't need to be visited. *)
    Hashtbl.find_opt rule_tbl name
  in
  let visited = Hashtbl.create 100 in
  let mark_visited name = Hashtbl.replace visited name () in
  let was_visited name = Hashtbl.mem visited name in
  let rec scan x =
    match (x : Tree_sitter_t.rule_body) with
    | SYMBOL name ->
        if not (was_visited name) then
          visit name
    | STRING _
    | PATTERN _
    | BLANK -> ()
    | IMMEDIATE_TOKEN x
    | TOKEN x
    | REPEAT x
    | REPEAT1 x -> scan x
    | CHOICE l
    | SEQ l -> List.iter scan l
    | PREC (_, x)
    | PREC_DYNAMIC (_, x)
    | PREC_LEFT (_, x)
    | PREC_RIGHT (_, x)
    | FIELD (_, x) -> scan x
    | ALIAS { value = name; content; _ } ->
        if not (was_visited name) then
          visit name;
        scan content
  and visit name =
    mark_visited name;
    match get_rule name with
    | None -> ()
    | Some x -> scan x
  in
  visit entrypoint;
  was_visited

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
  let name, is_inlined =
    match opt_rule_name with
    | Some rule_name -> rule_name, false
    | None -> cst, true
  in
  Token {
    name;
    is_inlined;
    description = Constant cst
  }

(*
   Unlike string constants, patterns without a name are omitted from
   tree-sitter's output. This is not desirable. Normally, we apply a pass
   on the grammar (see Simplify_grammar.ml) to make sure patterns
   have a name and show up in the parse tree.
*)
let translate_pattern opt_rule_name pat =
  match opt_rule_name with
  | Some name -> Token { name; is_inlined = false; description = Pattern pat }
  | None -> Blank

(*
   We discard the rules describing how to parse a token since we don't
   need them.
*)
let translate_token opt_rule_name token_contents =
  match name_of_body opt_rule_name token_contents with
  | Some name -> Token { name; is_inlined = false; description = Token }
  | None ->
      match Missing_node.token_produces_node token_contents with
      | Some (Literal cst) ->
          translate_constant opt_rule_name cst
      | Some (Name name) ->
          Token { name; is_inlined = false; description = Token }
      | None -> Blank

(*
   Remove constructs that are not relevant to us, such as precedence levels.
*)
let rec strip (x : Tree_sitter_t.rule_body) : Tree_sitter_t.rule_body =
  match x with
  | SYMBOL _
  | STRING _
  | PATTERN _
  | BLANK as x -> x
  | IMMEDIATE_TOKEN body -> IMMEDIATE_TOKEN (strip body)
  | TOKEN body -> TOKEN (strip body)
  | REPEAT x -> REPEAT (strip x)
  | REPEAT1 x -> REPEAT1 (strip x)
  | CHOICE l -> CHOICE (List.map strip l)
  | SEQ l -> SEQ (List.map strip l)
  | PREC (_, x)
  | PREC_DYNAMIC (_, x)
  | PREC_LEFT (_, x)
  | PREC_RIGHT (_, x) -> strip x
  | FIELD (_, x) -> strip x
  | ALIAS alias -> ALIAS { alias with content = strip alias.content }

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
    | STRING cst
    | IMMEDIATE_TOKEN (STRING cst) -> translate_constant rule_name cst
    | PATTERN pat
    | IMMEDIATE_TOKEN (PATTERN pat) -> translate_pattern rule_name pat
    | IMMEDIATE_TOKEN body
    | TOKEN body -> translate_token rule_name body
    | BLANK -> Blank
    | REPEAT x -> Repeat (translate x)
    | REPEAT1 x -> Repeat1 (translate x)
    | CHOICE [x; BLANK] -> Optional (translate x)
    | CHOICE l -> Choice (translate_choice rule_name l)
    | SEQ l -> Seq (List.map translate l)
    | ALIAS x ->
        assert x.must_be_preserved;
        Alias (x.value, translate x.content)
    | PREC _ -> assert false
    | PREC_DYNAMIC _ -> assert false
    | PREC_LEFT _ -> assert false
    | PREC_RIGHT _ -> assert false
    | FIELD _ -> assert false

  and translate_choice opt_rule_name cases =
    let translated_cases = List.map translate cases |> Util_list.deduplicate in
    Type_name.assign_case_names ?rule_name:opt_rule_name translated_cases
  in
  translate ~rule_name (strip x)

(*
   Algorithm: convert the nodes of tree from unnormalized to normalized,
   starting from the leaves. This ensures that the argument of flatten_seq
   is already fully normalized.

   We no longer flatten choices because they're rarely nested anyway,
   and it would require re-generating case names so as to avoid ambiguities.
*)
let rec normalize x =
  match x with
  | Symbol _
  | Token _
  | Blank
  | Alias _ as x -> x
  | Repeat x -> Repeat (normalize x)
  | Repeat1 x -> Repeat1 (normalize x)
  | Choice l ->
      Choice (List.map (fun (name, body) -> (name, normalize body)) l)
  | Optional x -> Optional (normalize x)
  | Seq l -> Seq (List.map normalize l |> flatten_seq)

and flatten_seq normalized_list =
  normalized_list
  |> List.map (function
    | Seq l -> l
    | other -> [other]
  )
  |> List.flatten

let make_external_rules externals =
  List.filter_map (fun rule_body ->
    match (rule_body : Tree_sitter_t.rule_body) with
    | SYMBOL name ->
        let body =
          Token { name; is_inlined = false; description = External }
        in
        Some (name, body)
    | STRING _ -> None (* no need for a rule *)
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
    let rec_group =
      match group with
      | [] -> assert false
      | [_] -> false
      | _ -> true
    in
    List.map (fun (is_rec, rule) ->
      let is_rec = rec_group || is_rec in
      { rule with is_rec }
    ) group
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

(*
   Don't allow references to extra tokens (e.g. ordinary whitespace)
   in rules.
*)
let forbid_explicit_extras ~is_used extras =
  match List.filter is_used extras with
  | [] -> ()
  | explicit_extras ->
      let names =
        explicit_extras
        |> List.map (fun extra -> sprintf "  %s" extra)
        |> String.concat "\n"
      in
      let msg =
        sprintf "\
The following tokens are declared as extras and thus can occur
anywhere in a program, but they are also referenced explicitly in some
rules:

%s

This prevents the ocaml-tree-sitter runtime from recovering a typed tree
from the tree-sitter untyped tree. To avoid this problem, create a separate
rule to define the token that's referenced in a rule and don't declare it
as an extra."
          names
      in
      failwith msg

let of_tree_sitter (x : Tree_sitter_t.grammar) : t =
  let entrypoint =
    (* assuming the grammar's entrypoint is the first rule in grammar.json *)
    match x.rules with
    | (name, _) :: _ -> name
    | _ -> "program"
  in
  let is_used = detect_used ~entrypoint x.rules in
  let grammar_rules = translate_rules x.rules in
  let all_rules =
    make_external_rules x.externals @ grammar_rules
    |> List.map (fun (name, body) ->
      let is_inlined_rule = not (is_used name) in
      {
        name;
        body;
        is_rec = true; (* set correctly by tsort below *)
        is_inlined_rule = is_inlined_rule;
        is_inlined_type = false
      }
    )
  in
  let sorted_rules = tsort_rules all_rules in
  let extras = filter_extras x.extras in
  forbid_explicit_extras ~is_used extras;
  {
    name = x.name;
    entrypoint;
    rules = sorted_rules;
    extras;
  }
  |> Rectypes.prevent_cyclic_type_abbreviations
