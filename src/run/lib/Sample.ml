(*
   Sample code that would normally be generated.

   The idea is to serve as a guide when writing or modifying the code
   generator.
*)

(* Disable warnings against unused variables *)
[@@@warning "-26-27"]

module CST = struct
  type number = (Loc.t * string) (* pattern "\\d+" *)
  type variable = (Loc.t * string) (* pattern "\\a\\w*" *)
  type expression = [
    | `Var of variable
    | `Num of number
    | `Exp_PLUS_exp of (expression * (Loc.t * string (* "+" *)) * expression)
  ]
  type statement = (expression * (Loc.t * string (* ";" *)))
  type program = statement list (* zero or more *)
end

module Parse = struct
  (* open Tree_sitter_run *)

  (*
  external create_parser :
    unit -> Tree_sitter_API.ts_parser = "octs_create_parser_XXX"
  *)

  let create_parser () : Tree_sitter_bindings.Tree_sitter_API.ts_parser =
    failwith "not implemented"

  let ts_parser () = create_parser ()

  (* generated *)
  let children_regexps : (string * string Matcher.Exp.t) list = [
    "expression",
    Alt [|
      Token "variable";
      Token "number";
      Seq [
        Token "expression";
        Token "+";
        Token "expression";
      ]
    |];
  ]

  type mt = Run.matcher_token

  let parse_source_file src_file =
    Tree_sitter_parsing.parse_source_file (ts_parser ()) src_file

  (* generated *)
  let trans_variable ((name, capture) : mt) : CST.variable =
    match capture with
    | Leaf v -> v
    | _ -> assert false

  (* generated *)
  let trans_number ((name, capture) : mt) : CST.number =
    match capture with
    | Leaf v -> v
    | _ -> assert false

  (* generated *)
  let rec trans_expression ((name, capture) : mt) : CST.expression =
    match capture with
    | Children v ->
        (match v with
         | Alt (0, v) ->
             `Var (trans_variable (Run.matcher_token v))
         | Alt (1, v) ->
             `Num (trans_number (Run.matcher_token v))
         | Alt (2, v) ->
             `Exp_PLUS_exp (
               match v with
               | Seq [v1; v2; v3] ->
                   let v1 = trans_expression (Run.matcher_token v1) in
                   let v2 = Run.trans_token (Run.matcher_token v2) in
                   let v3 = trans_expression (Run.matcher_token v3) in
                   (v1, v2, v3)
               | _ -> assert false
             )
         | _ -> assert false
        )
    | _ -> assert false

  (* generated *)
  let trans_statement ((name, capture) : mt) =
    match capture with
    | Children v ->
        (match v with
         | Seq [v1; v2] ->
             (trans_expression (Run.matcher_token v1),
              Run.trans_token (Run.matcher_token v2))
         | _ -> assert false
        )
    | _ -> assert false

  (* generated *)
  let trans_program ((name, capture) : mt) =
    match capture with
    | Children v ->
        Run.repeat (fun v -> trans_statement (Run.matcher_token v)) v
    | _ -> assert false

  let parse_input_tree input_tree =
    let root_node = Tree_sitter_parsing.root input_tree in
    let src = Tree_sitter_parsing.src input_tree in
    let match_node = Run.make_node_matcher children_regexps src in
    let matched_tree = match_node root_node in
    trans_program matched_tree
end
