(*
   Rewrite grammar.json to make it usable by ocaml-tree-sitter.
*)

open Printf
open Tree_sitter_t

(* Remove leading underscores which otherwise tell tree-sitter that the
   rule is hidden. *)
let rec remove_leading_underscores s =
  if s = "" then "x"
  else if s.[0] <> '_' then s
  else
    String.sub s 1 (String.length s - 1)
    |> remove_leading_underscores

(*
   Create a function that removes the leading underscores and avoids conflicts
   by appending a suffix as needed.

     "foo" -> "foo"
     "_bar" -> "bar"   // eliminate leading underscore
     "bar" -> "bar_"   // append a suffix because 'bar' is taken
     "_bar" -> "bar"   // '_bar' still maps to the same thing as earlier
     "_foo" -> "foo_"  // append a suffix because 'foo' is taken
*)
let make_name_translator () =
  let registry = Protect_ident.create ~reserved:[] () in
  fun name ->
    let preferred_name = remove_leading_underscores name in
    Protect_ident.translate registry preferred_name

let simplify_rule_body translate_name =
  let rec simplify x =
    match x with
    | SYMBOL name -> SYMBOL (translate_name name)
    | STRING _
    | PATTERN _
    | BLANK -> x
    | REPEAT x -> REPEAT (simplify x)
    | REPEAT1 x -> REPEAT1 (simplify x)
    | CHOICE xs -> CHOICE (List.map simplify xs)
    | SEQ xs -> SEQ (List.map simplify xs)
    | PREC (prec, x) -> PREC (prec, simplify x)
    | PREC_DYNAMIC (prec, x) -> PREC_DYNAMIC (prec, simplify x)
    | PREC_LEFT (prec, x) -> PREC_LEFT (prec, simplify x)
    | PREC_RIGHT (prec, x) -> PREC_RIGHT (prec, simplify x)
    | ALIAS alias ->
        (* remove the alias *)
        simplify alias.content
    | FIELD (field_name, x) -> FIELD (field_name, simplify x)
    | IMMEDIATE_TOKEN x -> IMMEDIATE_TOKEN (simplify x)
    | TOKEN x -> TOKEN (simplify x)
  in
  simplify

let simplify_grammar grammar =
  let translate_name = make_name_translator () in
  let simplify = simplify_rule_body translate_name in
  let simplified_rules =
    List.map (fun (name, rule_body) ->
      (translate_name name, simplify rule_body)
    ) grammar.rules
  in
  {
    name = grammar.name;
    rules = simplified_rules;
    extras = List.map simplify grammar.extras;
    inline = List.map translate_name grammar.inline;
    conflicts = List.map (List.map translate_name) grammar.conflicts;
    externals = List.map simplify grammar.externals;
    word = Option.map translate_name grammar.word;
    supertypes = []; (* removed *)
  }

let run ic oc =
  let orig_grammar =
    Atdgen_runtime.Util.Json.from_channel Tree_sitter_j.read_grammar ic
  in
  let new_grammar = simplify_grammar orig_grammar in
  let compact_json =
    Atdgen_runtime.Util.Json.to_string Tree_sitter_j.write_grammar new_grammar
  in
  let pretty_json = Yojson.Safe.prettify compact_json in
  fprintf oc "%s\n%!" pretty_json
