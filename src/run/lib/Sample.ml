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

    let parse_number = _parse_token "number" in
    let parse_variable = _parse_token "variable" in
    let rec parse_expression nodes =
      (match parse_variable nodes with
       | Some (e, [](*last*)) ->
           Some (`Case0 e, [](*last*))
       | _ (* last *) ->
           (match parse_number nodes with
            | Some (e, [](*last*)) ->
                Some (`Case1 e, [](*last*))
            | _ (* last *) ->
                let seq_start = nodes in
                match parse_expression nodes with
                | Some (e1, nodes) ->
                    (match _parse_token "+" nodes with
                     | Some (e2, nodes) ->
                         (match parse_expression nodes with
                          | Some (e3, [](* last *)) ->
                              Some (`Case2 (e1, e2, e3), [](* last *))
                          | _ (* last *) ->
                              None
                         )
                     | None ->
                         None
                    )
                | None ->
                    None
           )
      )
    in
    let parse_statement nodes =
      (match parse_expression nodes with
       | Some (e1, nodes) ->
           (match _parse_token ";" nodes with
            | Some (e2, [](*last*)) ->
                Some ((e1, e2), [](*last*))
            | _ (* last *) ->
                None
           )
       | None ->
           None
      )
    in
    let parse_program nodes =
      Combine.parse_repeat parse_statement nodes
    in
    parse_program
end
