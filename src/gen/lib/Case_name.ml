(*
   Assign good names to productions in the grammar, based on the
   enclosing rule name and the contents of the production.
*)

open Printf
open AST_grammar

let string_filter s f =
  let buf = Buffer.create 100 in
  for i = 0 to String.length s - 1 do
    let c = s.[i] in
    if f c then
      Buffer.add_char buf c
  done;
  Buffer.contents buf

let string_filter_map s f =
  let buf = Buffer.create 100 in
  for i = 0 to String.length s - 1 do
    match f s.[i] with
    | "" -> ()
    | chunk -> Buffer.add_string buf chunk
  done;
  Buffer.contents buf

let is_lowercase c =
  match c with
  | 'a'..'z' -> true
  | _ -> false

let is_uppercase c =
  match c with
  | 'A'..'Z' -> true
  | _ -> false

(* alphabetic letter? *)
let is_alpha c =
  match c with
  | 'A'..'Z'
  | 'a'..'z' -> true
  | _ -> false

(* alphabetic letter or other character allowed in an ocaml variable? *)
let is_alphanum c =
  match c with
  | 'A'..'Z'
  | 'a'..'z'
  | '0'..'9'
  | '_' -> true
  | _ -> false

let replace_first_char s ~default f =
  match s with
  | "" -> default
  | _ -> f s.[0]

let filter_alphanum s =
  string_filter s is_alphanum

let capital_prefix = "X_"

let force_capitalize s =
  let need_prefix =
    s = "" || not (is_alpha s.[0])
  in
  if need_prefix then
    capital_prefix ^ s
  else
    String.capitalize_ascii s

(*
   "Ab_c" -> Some "Ab_c"
   "ab_c" -> Some "Ab_c"
   "_" -> Some "X__"
   "53" -> Some "X_53"
   "" -> None
   "^%*$" -> None
*)
let normalize_case_prefix s =
  let s = filter_alphanum s in
  replace_first_char s ~default:None (fun c ->
    if is_alpha c then
      Some (String.capitalize_ascii s)
    else
      Some ("X_" ^ s)
  )

let make_case_prefix opt_rule_name =
  let orig_name =
    match opt_rule_name with
    | None -> ""
    | Some s -> Abbrev.words s
  in
  normalize_case_prefix orig_name

let name_of_token (token : token) =
  Punct.to_alphanum token.name

(*
   Derive a name from the structure of a rule, one that's hopefully not
   ambiguous, not too long, and stable over time.
*)
let name_rule_body body =
  let rec name_rule_body body =
    match body with
    | Symbol ident -> ident
    | Token token -> name_of_token token
    | Blank -> "blank"
    | Repeat body -> "rep_" ^ name_rule_body body
    | Repeat1 body -> "rep1_" ^ name_rule_body body
    | Choice ((_name, body) :: _) -> "choice_" ^ name_rule_body body
    | Choice [] -> "choice"
    | Optional body -> "opt_" ^ name_rule_body body
    | Seq l ->
        List.map name_rule_body l
        |> String.concat "_"
  in
  let full_name = name_rule_body body in
  Abbrev.words full_name

(*
   Hash a string with MD5 (it's overkill but standard and sufficiently fast
   for what we do with it) and keep only the beginning.
*)
let hash_string_hex s =
  let md5_hex =
    Digest.string s
    |> Digest.to_hex
  in
  assert (String.length md5_hex = 32);
  String.sub md5_hex 0 7

(*
   Similar to name_rule_body but recursively descend into alternatives,
   producing a longer name. Which is then hashed and discarded.
*)
let hash_hex body =
  let buf = Buffer.create 100 in
  let rec aux = function
    | Symbol ident -> Buffer.add_string buf ident
    | Token token -> Buffer.add_string buf token.name
    | Blank -> Buffer.add_string buf "blank"
    | Repeat body ->
        Buffer.add_string buf "repeat(";
        aux body;
        Buffer.add_char buf ')'
    | Repeat1 body ->
        Buffer.add_string buf "repeat1(";
        aux body;
        Buffer.add_char buf ')'
    | Choice cases ->
        Buffer.add_string buf "choice(";
        List.iter (fun (name, _) -> bprintf buf "%s," name) cases;
        Buffer.add_char buf ')'
    | Optional body ->
        Buffer.add_string buf "optional(";
        aux body;
        Buffer.add_char buf ')'
    | Seq l ->
        Buffer.add_string buf "seq(";
        List.iter aux l;
        Buffer.add_char buf ')'
  in
  aux body;
  let name = Buffer.contents buf in
  hash_string_hex name

let assign opt_rule_name cases =
  let prefix = make_case_prefix opt_rule_name in
  let initial_naming =
    List.mapi (fun pos rule_body ->
      let case_name = name_rule_body rule_body in
      let name =
        match prefix with
        | None -> force_capitalize case_name
        | Some prefix -> prefix ^ "_" ^ case_name
      in
      (name, (pos, rule_body))
    ) cases
  in
  let grouped = Util_list.group_by_key initial_naming in
  let disambiguated_naming =
    List.map (fun (name, group) ->
      match group with
      | [(pos, rule_body)] -> [(pos, (name, rule_body))]
      | [] -> assert false
      | rule_bodies ->
          List.map (fun (pos, rule_body) ->
            let hex_id = hash_hex rule_body in
            (pos, (name ^ "_" ^ hex_id, rule_body))
          ) rule_bodies
    ) grouped
    |> List.flatten
    |> List.sort (fun (a, _) (b, _) -> compare a b)
    |> List.map snd
  in
  let names = List.map fst disambiguated_naming in
  if not (Util_list.is_deduplicated names) then
    failwith (
      sprintf "\
Failed to assign unique names to choices for rule %s.
Names we came up with are:
%s"
        (match opt_rule_name with
         | None -> "<no name>"
         | Some name -> name)
        (List.map (fun name -> "  " ^ name) names |> String.concat "\n")
    );
  disambiguated_naming
