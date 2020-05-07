(*
   Convert between tree-sitter's representation of variants
   e.g. {"type": "SYMBOL", "name": "foo"} and atd's convention
   e.g. ["SYMBOL", "foo"].

   This is used in Tree_sitter.atd.
*)

type json = Yojson.Safe.t

(* local exception *)
exception Malformed

let get_field name fields =
  try List.assoc name fields
  with Not_found -> raise Malformed

let get_opt_field name fields =
  try List.assoc name fields
  with Not_found -> `Null

let get_string = function
  | `String s -> s
  | _ -> raise Malformed

let normalize_variant_object fields =
  let get k = get_field k fields in
  let opt k = get_opt_field k fields in
  let name = get "type" |> get_string in
  let value =
    match name with
    | "SYMBOL" -> get "name"
    | "STRING" -> get "value"
    | "PATTERN" -> get "value"
    | "REPEAT" -> get "content"
    | "CHOICE" -> get "members"
    | "SEQ" -> get "members"
    | "PREC" -> `List [get "value"; get "content"]
    | "PREC_DYNAMIC" -> `List [get "value"; get "content"]
    | "PREC_LEFT" -> `List [opt "value"; get "content"]
    | "PREC_RIGHT" -> `List [opt "value"; get "content"]
    | _ -> raise Malformed
  in
  `List [`String name; value]

(*
   Convert {type: name; <other fields>} to [name, <atom or tuple>].

   If the input is malformed, we leave it unchanged and we let atdgen
   emit a useful error message.
*)
let normalize (json : json) : json =
  match json with
  | `Assoc fields -> normalize_variant_object fields
  | json -> json
  | exception Malformed -> json

(* Convert back to tree-sitter format *)
let restore (_json : json) : json =
  failwith "TODO"
