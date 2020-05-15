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

  let parse input_file =
    let input = Input_file.load input_file in
    let get_token x =
      Input_file.get_token input x.startPosition x.endPosition in

    let _parse_token type_ =
      Combine.parse_node (fun x ->
        if x.type_ = type_ then
          Some (get_loc x, get_token x)
        else
          None
      )
    in

    let parse_number nodes =
      (
        _parse_token "number"
      ) nodes
    in
    let parse_variable nodes =
      (
        _parse_token "variable"
      ) nodes
    in
    let rec parse_expression nodes =
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
            let parse_elt = _parse_token "+" in
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
    in
    let parse_statement nodes =
      (* (parse_expression &&& parse_token ";" &&& parse_end) nodes *)
      let parse_nested =
        let parse_elt = parse_expression in
        let parse_tail =
          let parse_elt = _parse_token ";" in
          Combine.parse_last parse_elt
        in
        Combine.parse_seq parse_elt parse_tail
      in
      match parse_nested nodes with
      | Some ((e1, e2), nodes) -> Some (`Case2 (e1, e2), nodes)
      | None -> None
    in
    let parse_program nodes =
      Combine.parse_repeat (
        parse_statement
      ) nodes
    in
    parse_program
end
