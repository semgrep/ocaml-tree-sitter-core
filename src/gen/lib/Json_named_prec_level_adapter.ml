(*
   Fix up json representing a 'named_prec_level' in Tree_sitter.atd.

   Implements the standard interface expected by Tree_sitter.atd.
*)

type json = Yojson.Safe.t

let get_field name fields =
  try List.assoc name fields
  with Not_found -> `Null

let normalize (json : json) : json =
  match json with
  | `Assoc fields ->
      (match get_field "type" fields with
       | `String "SYMBOL" ->
           `List [ `String "Prec_symbol"; get_field "name" fields ]
       | `String "STRING" ->
           `List [ `String "Prec_string"; get_field "value" fields ]
       | _ -> json
      )
  | malformed -> malformed

let restore (json : json) : json =
  match json with
  | `List [ `String "Prec_symbol"; name ] ->
      `Assoc [
        "type", `String "SYMBOL";
        "name", name;
      ]
  | `List [ `String "Prec_string"; value ] ->
      `Assoc [
        "type", `String "STRING";
        "value", value;
      ]
  | malformed -> malformed
