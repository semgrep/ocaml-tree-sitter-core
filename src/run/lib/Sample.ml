(*
   Sample code that would normally be generated.

   The idea is to serve as a guide when writing or modifying the code
   generator.
*)

(*
   Disable warning 42:
     "this use of Foo relies on type-directed disambiguation,
      it will not compile with OCaml 4.00 or earlier."
*)
[@@@warning "-42"]

(* Disable warnings against unused variables. *)
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
  type comment = (Loc.t * string)
  type extra = [
    | `Comment of (Loc.t * comment)
  ]
end

module Parse = struct
  open Tree_sitter_bindings.Tree_sitter_output_t

  let debug = ref false

  (*
  external create_parser :
    unit -> Tree_sitter_API.ts_parser = "octs_create_parser_XXX"
  *)

  let create_parser () : Tree_sitter_bindings.Tree_sitter_API.ts_parser =
    failwith "not implemented"

  let ts_parser = lazy (create_parser ())

  let parse_source_string ?src_file contents =
    Tree_sitter_parsing.parse_source_string ?src_file
      (Lazy.force ts_parser) contents

  let parse_source_file src_file =
    Tree_sitter_parsing.parse_source_file
      (Lazy.force ts_parser) src_file

  (* generated *)
  let extras = [
    "comment";
  ]

  (* generated *)
  let trans_variable (src : Src_file.t) (node : node)
      : CST.variable =
    Run.token src node

  (* generated *)
  let trans_number (src : Src_file.t) (node : node)
      : CST.number =
    Run.token src node

  (* generated *)
  let rec trans_expression (src : Src_file.t) (node : node)
      : CST.expression =
    let children = Run.children node in
    match Run.select children [
      [Name "variable"];
      [Name "number"];
      [Name "expression"; Literal "+"; Name "expression"];
    ] with
    | 0, _ ->
        `Var (
          trans_variable src (List.nth children 0)
        )
    | 1, _ ->
        `Num (
          trans_number src (List.nth children 0)
        )
    | 2, _ ->
        `Exp_PLUS_exp (
          trans_expression src (List.nth children 0),
          Run.token src (List.nth children 1),
          trans_expression src (List.nth children 2))
    | _ -> Run.fail node "expression"

  (* generated *)
  let trans_statement (src : Src_file.t) (node : node) =
    let children = Run.children node in
    (trans_expression src (List.nth children 0),
     Run.token src (List.nth children 1))

  (* generated - entrypoint *)
  let trans_program (src : Src_file.t) (node : node) =
    List.map (trans_statement src) (Run.children node)

  (* generated - extra *)
  let trans_comment (src : Src_file.t) (node : node) : CST.comment =
    Run.token src node

  let translate_tree src node trans_x =
    match node.kind with
    | Error -> None
    | _ -> Some (trans_x src node)

  (* generated *)
  let translate_extra src
      (node : Tree_sitter_bindings.Tree_sitter_output_t.node)
    : CST.extra option =
    match node.type_ with
    | "comment" ->
        (match translate_tree src node trans_comment with
         | None -> None
         | Some x -> Some (`Comment (Run.get_loc node, x)))
    | _ -> None

  (* generated *)
  let translate_root src root_node =
    translate_tree src root_node trans_program

  let parse_input_tree input_tree =
    let orig_root_node = Tree_sitter_parsing.root input_tree in
    let src = Tree_sitter_parsing.src input_tree in
    let errors = Run.extract_errors src orig_root_node in
    let opt_program, extras =
      Run.translate
        ~extras
        ~translate_root:(translate_root src)
        ~translate_extra:(translate_extra src)
        orig_root_node
    in
    Parsing_result.create src opt_program extras errors

  let string ?src_file contents =
    let input_tree = parse_source_string ?src_file contents in
    parse_input_tree input_tree

  let file src_file =
    let input_tree = parse_source_file src_file in
    parse_input_tree input_tree

end
