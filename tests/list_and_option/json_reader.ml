open Common
module J = Json_type

(* helpers *)
type 'a json_reader = J.json_type list -> 'a option * J.json_type list

let error s json =
  let str = Json_io.string_of_json json in
  pr2 str;
  failwith (spf "Wrong format: %s, got: %s" s str)
let error2 s xs =
  let str = Json_io.string_of_json (J.Array xs) in
  pr2 str;
  failwith (spf "Wrong format: %s, got: %s" s str)


let (parse_STRING: string -> string json_reader) = fun stype xs ->
  match xs with
  | (J.Object ["type", J.String s;
               "children", J.Array []])::xs when s = stype ->
    Some "", xs
  | _ -> None, xs


let rec (parse_REPEAT: 'a json_reader -> 'a list json_reader) = fun f xs ->
  match f xs with
  | Some e, xs -> 
    (match parse_REPEAT f xs with
    | Some es, xs -> Some (e::es), xs
    | None, xs -> None, xs
    )
  | None, xs -> Some [], xs

let (parse_OPTIONAL: 'a json_reader -> 'a option json_reader) = fun f xs ->
  match f xs with
  | Some (e), xs -> Some (Some e), xs
  | None, xs -> Some (None), xs

(* parse_SEQ *)
let (>>=) res_parser1 parser2_closure =
  match res_parser1 with
  | None, xs -> None, xs
  | Some e, xs -> parser2_closure (e, xs)

(* start of specific parser *)
open Ast

let rec (parse_program: program json_reader) = fun xs ->
  match xs with
  | (J.Object ["type", J.String "program";
              "children", J.Array xs])::ys ->
    parse_a_rule xs >>= (fun (v1, xs) ->
    parse_REPEAT parse_b_rule xs >>= (fun (v2, xs) ->
    parse_OPTIONAL parse_c_rule xs >>= (fun (v3, xs) ->
    parse_d_rule xs >>= (fun (v4, xs) ->
    parse_e_rule_alias xs >>= (fun (v5, xs) ->
    parse_f_rule_alias xs >>= (fun (v6, xs) ->
      if xs = []
      then Some (v1, v2, v3, v4, v5, v6), ys
      else error2 "parse_program: remaining json elements" xs
    ))))))
  | _ -> None, xs

and (parse_e_rule_alias: e_rule_alias json_reader) = fun xs ->
  match xs with
  | (J.Object ["type", J.String "e_rule_alias";
              "children", J.Array xs])::ys ->
    parse_e_rule xs >>= (fun (v1, xs) ->
      if xs = []
      then Some v1, ys
      else error2 "parse_e_rule_alias: remaining json elements" xs
    )
  | _ -> None, xs

and (parse_f_rule_alias: f_rule_alias json_reader) = fun xs ->
  match xs with
  | (J.Object ["type", J.String "f_rule_alias";
              "children", J.Array xs])::ys ->
    parse_f_rule xs >>= (fun (v1, xs) ->
      if xs = []
      then Some v1, ys
      else error2 "parse_f_rule_alias: remaining json elements" xs
    )
  | _ -> None, xs

and (parse_a_rule: a_rule json_reader) = parse_STRING "a_rule"
and (parse_b_rule: b_rule json_reader) = parse_STRING "b_rule"
and (parse_c_rule: c_rule json_reader) = parse_STRING "c_rule"
and (parse_d_rule: d_rule json_reader) = parse_STRING "d_rule"
and (parse_e_rule: e_rule json_reader) = parse_STRING "e_rule"
and (parse_f_rule: f_rule json_reader) = parse_STRING "f_rule"

(* entry point *)
let parse file = 
  let json = Json_io.load_json file in
  match parse_program [json] with
  | Some e, [] -> e
  | Some _, xs -> error2 "parse: remaining json elements" xs
  | None, xs -> error2 "parse: unrecognized" xs
