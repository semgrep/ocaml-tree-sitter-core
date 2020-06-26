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
  let registry = Protect_ident.create ~reserved:[] in
  fun name ->
    let preferred_name = remove_leading_underscores name in
    Protect_ident.reserve registry ~src:name ~preferred_dst:preferred_name

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

(* The tree-sitter documentation says:

     inline - an array of rule names that should be automatically
     removed from the grammar by replacing all of their usages with a
     copy of their definition. This is useful for rules that are used in
     multiple places but for which you don’t want to create syntax tree
     nodes at runtime.

   We perform this inlining here, on 'grammar.json' so we don't have to do
   it later.

   Alternatively, we could simply set grammar.inline = [] to disable
   inlining, going against the preferences of the grammar author.
*)
let apply_inline grammar =
  let rules = Hashtbl.create 100 in
  List.iter (fun (name, body) -> Hashtbl.add rules name body) grammar.rules;
  let inline_rules = Hashtbl.create 100 in
  List.iter (fun name ->
    match Hashtbl.find_opt rules name with
    | None -> () (* could be a warning *)
    | Some body -> Hashtbl.add inline_rules name body
  ) grammar.inline;

  let is_inlined name =
    Hashtbl.mem inline_rules name in

  let get_inlined_body name =
    Hashtbl.find_opt inline_rules name in

  (* parents = stack of rule names being inlined, used to detect cycles. *)
  let rec inline parents x =
    match x with
    | SYMBOL name ->
        (match get_inlined_body name with
         | None -> SYMBOL name
         | Some body ->
             if List.mem name parents then
               failwith (
                 sprintf "Cannot inline rule %s due to cycle: %s"
                   name
                   (String.concat " -> " (name :: parents))
               )
             else
               inline (name :: parents) body
        )
    | STRING _
    | PATTERN _
    | BLANK -> x
    | REPEAT x -> REPEAT (inline parents x)
    | REPEAT1 x -> REPEAT1 (inline parents x)
    | CHOICE xs -> CHOICE (List.map (inline parents) xs)
    | SEQ xs -> SEQ (List.map (inline parents) xs)
    | PREC (prec, x) -> PREC (prec, inline parents x)
    | PREC_DYNAMIC (prec, x) -> PREC_DYNAMIC (prec, inline parents x)
    | PREC_LEFT (prec, x) -> PREC_LEFT (prec, inline parents x)
    | PREC_RIGHT (prec, x) -> PREC_RIGHT (prec, inline parents x)
    | ALIAS alias ->
        (* remove the alias *)
        inline parents alias.content
    | FIELD (field_name, x) -> FIELD (field_name, inline parents x)
    | IMMEDIATE_TOKEN x -> IMMEDIATE_TOKEN (inline parents x)
    | TOKEN x -> TOKEN (inline parents x)
  in
  let inline_rules rules =
    List.filter_map (fun (name, body) ->
      if is_inlined name then
        None
      else
        Some (name, inline [name] body)
    ) rules
  in
  { grammar with
    inline = [];
    rules = inline_rules grammar.rules }

let simplify_grammar grammar =
  let grammar = apply_inline grammar in
  let translate_name = make_name_translator () in
  let simplify = simplify_rule_body translate_name in
  let simplified_rules =
    List.map (fun (name, rule_body) ->
      (translate_name name, simplify rule_body)
    ) grammar.rules
  in
  {
    name = grammar.name;
    word = Option.map translate_name grammar.word;
    extras = List.map simplify grammar.extras;
    inline = [];
    conflicts = List.map (List.map translate_name) grammar.conflicts;
    externals = List.map simplify grammar.externals;
    supertypes = [];
    rules = simplified_rules;
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
