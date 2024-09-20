(*
   Convert a JSON grammar to JavaScript for better readability when
   debugging.
*)

open Printf
open Tree_sitter_t
open Indent.Types

let flatten nested_list =
  List.map (fun nodes -> Inline nodes) nested_list

let comma is_last s =
  if is_last then s
  else s ^ ","

(* Produce a javascript quoted string literal *)
let str s =
  Yojson.Safe.to_string (`String s)

let pattern s =
  sprintf "/%s/" s

let rule s =
  sprintf "$.%s" s

(*
   Move the leading underscore to the end of the string for sorting purposes:
     "_foo" -> "foo_"
*)
let move_leading_underscore str =
  if str <> "" && str.[0] = '_' then
    String.sub str 1 (String.length str - 1) ^ "_"
  else
    str

(*
   Compare rule names alphabetically, using the leading '_' only as a
   last-resort disambiguator to allow 'foo' and '_foo' to appear in the
   same region when comparing two grammars.
*)
let compare_rule_name a b =
  String.compare (move_leading_underscore a) (move_leading_underscore b)

(*
   This is for sorting choice() elements
*)
let compare_rule_body (a : rule_body) (b : rule_body) =
  match a, b with
  | SYMBOL a, SYMBOL b -> compare_rule_name a b
  | _ -> compare a b

let pp_conflict ?prefix:_ ?(is_last = true) rule_list =
  let rules = List.map rule rule_list |> String.concat ", " in
  [ Line (sprintf "[%s]" rules |> comma is_last) ]

let rec map
    (f : ?prefix:string -> ?is_last:bool -> _ -> _) xs =
  match xs with
  | [] -> []
  | [x] -> [f ~is_last:true x]
  | x :: xs -> f ~is_last:false x :: map f xs

let string_of_prec_value (x : prec_value) =
  match x with
  | Num_prec n -> string_of_int n
  | Named_prec name -> str name

let pp_value ~is_last (s : string) =
  [ Line (s |> comma is_last) ]

let pp_prec_value ~is_last x =
  let s = string_of_prec_value x in
  pp_value ~is_last s

(*
   The 'sort_choices' setting is the same for all recursive calls
   unlike the other options 'prefix' and 'is_last'.
*)
let pp_body ~sort_choices ?prefix ?is_last body =
  let rec pp_body ?(prefix = "") ?(is_last = true) body =
    let cons, args =
      match body with
      | SYMBOL s -> rule s, None
      | STRING s -> str s, None
      | PATTERN s -> pattern s, None
      | BLANK -> "\"\" /* blank */", None
      | REPEAT x -> "repeat", Some (pp_body x)
      | REPEAT1 x -> "repeat1", Some (pp_body x)
      | CHOICE [x; BLANK] -> "optional", Some (pp_body x)
      | CHOICE xs ->
          let xs =
            if sort_choices then
              List.sort compare_rule_body xs
            else
              xs
          in
          "choice", Some (map pp_body xs |> flatten)
      | SEQ xs -> "seq", Some (map pp_body xs |> flatten)
      | PREC (prec_value, x) ->
          "prec", Some [
            Inline (pp_prec_value ~is_last:false prec_value);
            Inline (pp_body ~is_last:true x);
          ]
      | PREC_DYNAMIC (n, x) ->
          "prec.dynamic", Some [
            Inline (pp_value ~is_last:false (string_of_int n));
            Inline (pp_body ~is_last:true x)
          ]
      | PREC_LEFT (opt_prec_value, x) ->
          "prec.left", Some (pp_opt_prec opt_prec_value x)
      | PREC_RIGHT (opt_prec_value, x) ->
          "prec.right", Some (pp_opt_prec opt_prec_value x)
      | ALIAS x -> "alias", Some (pp_alias x)
      | FIELD (name, x) -> "field", Some (pp_field name x)
      | IMMEDIATE_TOKEN x -> "token.immediate", Some (pp_body x)
      | TOKEN x -> "token", Some (pp_body x)
    in
    match args with
    | None ->
        [ Line (sprintf "%s%s" prefix (cons |> comma is_last)) ]
    | Some args ->
        [
          Line (sprintf "%s%s(" prefix cons);
          Block args;
          Line (")" |> comma is_last)
        ]

  and pp_opt_prec opt_prec_value x =
    let body = pp_body ~is_last:true x in
    match opt_prec_value with
    | None -> body
    | Some prec_value ->
        [
          Inline (pp_prec_value ~is_last:false prec_value);
          Inline body;
        ]

  and pp_alias x =
    let new_name =
      match x.named with
      | true -> rule x.value
      | false -> str x.value
    in
    [
      Inline (pp_body ~is_last:false x.content);
      Line new_name;
    ]

  and pp_field name x =
    [
      Line (str name ^ ",");
      Inline (pp_body ~is_last:true x);
    ]
  in
  pp_body ?prefix ?is_last body

let pp_rule ~sort_choices ?prefix:_ ?is_last (name, body) =
  pp_body ~sort_choices ~prefix:(sprintf "%s: $ => " name) ?is_last body

let pp_word (x : ident option) =
  match x with
  | None -> []
  | Some s -> [ Line (sprintf "word: $ => %s," (rule s)) ]

let string_of_named_prec_level x =
  match x with
  | Prec_symbol name -> rule name
  | Prec_string s -> str s

let pp_precedence_level ?prefix:_ ?(is_last = true) level =
  let level =
    level
    |> List.map string_of_named_prec_level
    |> String.concat ", "
  in
  [ Line (sprintf "[%s]" level |> comma is_last) ]

let pp_grammar ~sort_choices ~sort_rules (x : grammar) : Indent.t =
  let rules =
    if sort_rules then
      match x.rules with
      | entrypoint :: other_rules ->
          entrypoint
          :: List.sort (fun (a, _) (b, _) -> compare_rule_name a b) other_rules
      | [] -> []
    else
      x.rules
  in
  let pp_body = pp_body ~sort_choices in
  [
    Line
      "// JavaScript grammar recovered from JSON by 'ocaml-tree-sitter to-js'";
    Line "module.exports = grammar({";
    Block [
      Line (sprintf "name: %s," (str x.name));
      Inline (pp_word x.word);
      Line "externals: $ => [";
      Block (map pp_body x.externals |> flatten);
      Line "],";
      Line "conflicts: $ => [";
      Block (map pp_conflict x.conflicts |> flatten);
      Line "],";
      Line "inline: $ => [";
      Block (map (fun ?prefix:_ ?(is_last = true) name ->
        Line (rule name |> comma is_last)
      ) x.inline);
      Line "],";
      Line "precedences: $ => [";
      Block (map pp_precedence_level x.precedences |> flatten);
      Line "],";
      Line "supertypes: $ => [";
      Block (map (fun ?prefix:_ ?(is_last = true) name ->
        Line (rule name |> comma is_last)
      ) x.supertypes);
      Line "],";
      Line "extras: $ => [";
      Block (map pp_body x.extras |> flatten);
      Line "],";
      Line "rules: {";
      Block (map (pp_rule ~sort_choices) rules |> flatten);
      Line "}";
    ];
    Line "});";
  ]

let rec strip (body : rule_body) =
  match body with
  | SYMBOL _
  | STRING _
  | PATTERN _
  | BLANK -> body
  | REPEAT x -> REPEAT (strip x)
  | REPEAT1 x -> REPEAT1 (strip x)
  | CHOICE xs -> CHOICE (List.map strip xs)
  | SEQ xs -> SEQ (List.map strip xs)
  | PREC (_prec_value, x) -> strip x
  | PREC_DYNAMIC (_n, x) -> strip x
  | PREC_LEFT (_opt_prec_value, x) -> strip x
  | PREC_RIGHT (_opt_prec_value, x) -> strip x
  | ALIAS x -> strip x.content
  | FIELD (_name, x) -> strip x
  | IMMEDIATE_TOKEN x -> strip x
  | TOKEN x -> strip x

(*
   Eliminate all the constructs that don't affect the structure of the
   tree as reflected by the types in the generated file CST.ml.
*)
let strip_grammar (grammar : grammar) =
  {
    grammar with
    extras = List.map strip grammar.extras;
    inline = [];
    conflicts = [];
    precedences = [];
    externals = (* is this useful to keep? *) List.map strip grammar.externals;
    supertypes = [];
    rules = List.map (fun (name, body) -> (name, strip body)) grammar.rules;
  }

let run ~sort_choices ~sort_rules ~strip input_path output_path =
  let grammar =
    match input_path with
    | None ->
        Atdgen_runtime.Util.Json.from_channel Tree_sitter_j.read_grammar stdin
    | Some file ->
        Atdgen_runtime.Util.Json.from_file Tree_sitter_j.read_grammar file
  in
  let grammar = if strip then strip_grammar grammar else grammar in
  let tree = pp_grammar ~sort_choices ~sort_rules grammar in
  match output_path with
  | None -> Indent.to_channel stdout tree
  | Some file -> Indent.to_file file tree
