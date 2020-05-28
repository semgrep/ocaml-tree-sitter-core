(*
   Sample code that would normally be generated.

   The idea is to serve as a guide when writing or modifying the code
   generator.
*)

(* Disable warnings against unused variables *)
[@@@warning "-26-27"]

module AST = struct
  type number = (Loc.t * string) (* pattern "\\d+" *)
  type variable = (Loc.t * string) (* pattern "\\a\\w*" *)
  type expression = [
    | `Case0 of variable
    | `Case1 of number
    | `Case2 of (expression * (Loc.t * string (* "+" *)) * expression)
  ]
  type statement = (expression * (Loc.t * string (* ";" *)))
  type stmt = statement (* alias *)
  type _thing = statement (* inline alias *)
  type program = statement list (* zero or more *)
end

module Parse = struct
  open Tree_sitter_output_t
  let get_loc x = Loc.({ start = x.startPosition; end_ = x.endPosition})

  let parse ~src_file ~json_file =
    let input = Src_file.load src_file in

    let root_node =
      Atdgen_runtime.Util.Json.from_file
        Tree_sitter_output_j.read_node
        json_file
      |> Combine.assign_unique_ids
    in

    let get_token x =
      Src_file.get_token input x.startPosition x.endPosition in

    (* childless rule, from which we extract location and token. *)
    let _parse_leaf_rule type_ =
      Combine.parse_node (fun x ->
        if x.type_ = type_ then
          Some (get_loc x, get_token x)
        else
          None
      )
    in

    let cache_inline_expression = Combine.Memoize.create () in
    let cache_node_expression = Combine.Memoize.create () in

    let parse_node_number : AST.number Combine.reader = fun nodes ->
      (
        _parse_leaf_rule "number"
      ) nodes
    in
    let parse_node_variable nodes =
      (
        _parse_leaf_rule "variable"
      ) nodes
    in
    let rec parse_inline_expression : AST.expression Combine.reader =
      fun nodes ->
        let parse_tail = Combine.parse_success in
        let parse_case0 nodes =
          match
            (
              Combine.parse_seq parse_node_variable parse_tail
            )
              nodes
          with
          | Some ((res, ()), nodes) -> Some ((`Case0 res), nodes)
          | None -> None
        in
        let parse_case1 nodes =
          match
            (
              Combine.parse_seq parse_node_number parse_tail
            )
              nodes
          with
          | Some ((res, ()), nodes) -> Some ((`Case1 res), nodes)
          | None -> None
        in
        let parse_case2 nodes =
          match
            (
              let parse_tail =
                let parse_tail =
                  Combine.parse_seq parse_node_expression parse_tail
                in
                Combine.parse_seq (_parse_leaf_rule "+") parse_tail
              in
              Combine.parse_seq parse_node_expression parse_tail
            ) nodes
          with
          | Some ((e0, (e1, (e2, ()))), nodes) ->
              Some ((`Case2 (e0, e1, e2)), nodes)
          | None ->
              None
        in
        match parse_case0 nodes with
        | Some _ as res -> res
        | None ->
            match parse_case1 nodes with
            | Some _ as res -> res
            | None ->
                parse_case2 nodes
    and parse_children_expression : _ Combine.children_reader = fun nodes ->
      Combine.parse_full parse_inline_expression nodes
    and parse_node_expression = fun nodes ->
      Combine.Memoize.apply cache_node_expression (
        Combine.parse_rule "expression" parse_children_expression
      ) nodes
    in

    let cache_inline_statement = Combine.Memoize.create () in
    let cache_node_statement = Combine.Memoize.create () in
    let cache_node_stmt = Combine.Memoize.create () in

    let parse_inline_statement : AST.statement Combine.reader =
      fun nodes ->
        Combine.Memoize.apply cache_inline_statement (
          (fun nodes ->
             match
               Combine.parse_seq
                 parse_node_expression
                 (
                   Combine.parse_seq
                     (_parse_leaf_rule ";")
                     Combine.parse_success
                 )
                 nodes
             with
             | Some ((e1, (e2, ())), nodes) -> Some ((e1, e2), nodes)
             | None -> None
          )
        ) nodes
    in
    let parse_children_statement : _ Combine.children_reader = fun nodes ->
      Combine.parse_full parse_inline_statement nodes
    in
    (* normal rule (not inline, not an alias) *)
    let parse_node_statement : AST.statement Combine.reader = fun nodes ->
      Combine.Memoize.apply cache_node_statement (
        Combine.parse_rule "statement" parse_children_statement
      ) nodes
    in
    (* alias *)
    let parse_node_stmt : AST.stmt Combine.reader = fun nodes ->
      Combine.Memoize.apply cache_node_stmt (
        Combine.parse_rule "stmt" parse_children_statement
      ) nodes
    in
    (* inline alias *)
    let parse_inline__thing : AST._thing Combine.reader =
      fun nodes ->
        parse_inline_statement nodes
    in

    let parse_node_program = fun nodes ->
      Combine.parse_rule "program" (
        Combine.parse_repeat
          parse_node_statement
          Combine.parse_end
      ) nodes
    in
    parse_node_program [root_node]
end
