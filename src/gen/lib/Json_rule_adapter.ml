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
  let type_ = get "type" |> get_string in
  let opt_value =
    match type_ with
    | "SYMBOL" -> Some (get "name")
    | "STRING" -> Some (get "value")
    | "PATTERN" -> Some (get "value")
    | "BLANK" -> None (* found in json's grammar *)
    | "REPEAT" -> Some (get "content")
    | "REPEAT1" -> Some (get "content")
    | "CHOICE" -> Some (get "members")
    | "SEQ" -> Some (get "members")
    | "PREC" -> Some (`List [get "value"; get "content"])
    | "PREC_DYNAMIC" -> Some (`List [get "value"; get "content"])
    | "PREC_LEFT" -> Some (`List [opt "value"; get "content"])
    | "PREC_RIGHT" -> Some (`List [opt "value"; get "content"])
    | "ALIAS" -> Some (`Assoc fields)
    | "FIELD" -> Some (`List [get "name"; get "content"])
    | "IMMEDIATE_TOKEN" -> Some (get "content")
    | "TOKEN" -> Some (get "content")
    | _ -> raise Malformed
  in
  match opt_value with
  | None -> `String type_
  | Some value -> `List [`String type_; value]

(*
   Convert {type: name; <other fields>} to [name, <atom or tuple>].

   If the input is malformed, we leave it unchanged and we let atdgen
   emit a useful error message.
*)
let normalize (json : json) : json =
  try
    match json with
    | `Assoc fields -> normalize_variant_object fields
    | json -> json
  with Malformed -> json

(* Convert back to tree-sitter format *)
let restore (json : json) : json =
  let type_, opt_value =
    match json with
    | `String type_ -> type_, None
    | `List [`String type_; value] -> type_, Some value
    | _ -> assert false
  in
  let optional_fields =
    match opt_value with
    | None -> []
    | Some value ->
        match type_ with
        | "SYMBOL" -> ["name", value]
        | "STRING" -> ["value", value]
        | "PATTERN" -> ["value", value]
        | "BLANK" -> []
        | "REPEAT"
        | "REPEAT1" -> ["content", value]
        | "CHOICE" -> ["members", value]
        | "SEQ" -> ["members", value]
        | "PREC"
        | "PREC_DYNAMIC"
        | "PREC_LEFT"
        | "PREC_RIGHT" ->
            (match value with
             | `List [value; content] ->
                 ["value", value;
                  "content", content]
             | _ -> assert false
            )
        | "ALIAS" ->
            (match value with
             | `Assoc fields -> fields
             | _ -> assert false
            )
        | "FIELD" ->
            (match value with
             | `List [name; content] ->
                 ["name", name;
                  "content", content]
             | _ -> assert false
            )
        | "IMMEDIATE_TOKEN" -> ["content", value]
        | "TOKEN" -> ["content", value]
        | _ -> assert false
  in
  `Assoc (("type", `String type_) :: optional_fields)
