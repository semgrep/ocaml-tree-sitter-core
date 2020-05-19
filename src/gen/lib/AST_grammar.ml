(*
   Conversion and simplification from type specified in Tree_sitter.atd.
*)

type ident = string

type rule_body =
  (* atomic (leaves) *)
  | Symbol of ident
  | String of string
  | Pattern of string
  | Blank

  (* composite (nodes) *)
  | Repeat of rule_body
  | Repeat1 of rule_body
  | Choice of rule_body list
  | Optional of rule_body
  | Seq of rule_body list

type rule = (ident * rule_body)

type grammar = {
  name: ident;
  entrypoint: ident;
  rules: rule list;
}

(* alias *)
type t = grammar

(*
   Simple translation without normalization. Get rid of PREC_*
*)
let rec translate (x : Tree_sitter_t.rule_body) =
  match x with
  | SYMBOL ident -> Symbol ident
  | STRING s -> String s
  | PATTERN s -> Pattern s
  | BLANK -> Blank
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
  | ALIAS alias ->
      translate alias.content (* TODO probably good to not ignore *)
  | IMMEDIATE_TOKEN x -> translate x (* TODO check what this is *)
  | TOKEN x -> translate x

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
  | Blank as x -> x
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
    | Tree_sitter_t.SYMBOL name -> Some (name, String name)
    | Tree_sitter_t.STRING _ -> None (* no need for a rule *)
    | _ -> failwith "found member of 'externals' that's not a SYMBOL or STRING"
  ) externals

let translate_rules rules =
  List.map (fun (name, body) -> (name, translate body |> normalize)) rules

let of_tree_sitter (x : Tree_sitter_t.grammar) : t =
  let entrypoint =
    (* assuming the grammar's entrypoint is the first rule in grammar.json *)
    match x.rules with
    | (name, _) :: _ -> name
    | _ -> "program"
  in
  let grammar_rules = translate_rules x.rules in
  let all_rules = make_external_rules x.externals @ grammar_rules in
  {
    name = x.name;
    entrypoint;
    rules = all_rules;
  }
