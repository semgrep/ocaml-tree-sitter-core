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

    let _parse_rule type_ parse_children =
      Combine.parse_node (fun x ->
        if x.type_ = type_ then
          parse_children x.children
        else
          None
      )
    in

    (* childless rule, from which we extract location and token. *)
    let _parse_leaf_rule type_ =
      Combine.parse_node (fun x ->
        if x.type_ = type_ then
          Some (get_loc x, get_token x)
        else
          None
      )
    in

    let tbl_expression = Combine.Memoize.create () in
    let tbl_statement = Combine.Memoize.create () in

    let parse_number : AST.number Combine.reader = fun nodes ->
      (
        _parse_leaf_rule "number"
      ) nodes
    in
    let parse_variable nodes =
      (
        _parse_leaf_rule "variable"
      ) nodes
    in
    let rec parse_expression nodes =
      _parse_rule "expression" (fun nodes ->
        let parse_case0 nodes =
          match
            (
              let parse_elt = parse_variable in
              Combine.parse_last parse_elt
            )
              nodes
          with
          | Some (res, nodes) -> Some (`Case0 res, nodes)
          | None -> None
        in
        let parse_case1 nodes =
          match
            (
              let parse_elt = parse_number in
              Combine.parse_last parse_elt
            )
              nodes
          with
          | Some (res, nodes) -> Some (`Case1 res, nodes)
          | None -> None
        in
        let parse_case2 nodes =
          let parse_nested =
            let parse_elt = parse_expression in
            let parse_tail =
              let parse_elt = _parse_leaf_rule "+" in
              let parse_tail =
                let parse_elt = parse_expression in
                Combine.parse_last parse_elt
              in
              Combine.parse_seq parse_elt parse_tail
            in
            Combine.parse_seq parse_elt parse_tail
          in
          match parse_nested nodes with
          | Some ((e0, (e1, e2)), nodes) -> Some (`Case2 (e0, e1, e2), nodes)
          | None -> None
        in
        (* (parse_case0 ||| parse_case1 ||| parse_case2) nodes *)
        match parse_case0 nodes with
        | Some _ as res -> res
        | None ->
            match parse_case1 nodes with
            | Some _ as res -> res
            | None ->
                parse_case2 nodes
      ) nodes
    in
    let parse_statement nodes =
      Combine.Memoize.apply tbl_statement (
        _parse_rule "statement" (fun nodes ->
          (* (parse_expression &&& parse_leaf_rule ";" &&& parse_end) nodes *)
          let parse_nested =
            let parse_elt = parse_expression in
            let parse_tail =
              let parse_elt = _parse_leaf_rule ";" in
              Combine.parse_last parse_elt
            in
            Combine.parse_seq parse_elt parse_tail
          in
          match parse_nested nodes with
          | Some ((e1, e2), nodes) -> Some (`Case2 (e1, e2), nodes)
          | None -> None
        )
      ) nodes
    in
    let parse_program nodes =
      _parse_rule "program" (
        Combine.parse_repeat
          parse_statement
          Combine.parse_end
      ) nodes
    in
    parse_program [root_node]
end
