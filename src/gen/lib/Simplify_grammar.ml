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
   tree-sitter grammar rule names allows capitals but it's not idiomatic.
   An ocaml type name may not start a capital. Here, we just downcase
   everything.
*)
let normalize_name s =
  String.lowercase_ascii s

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
  let map = Protect_ident.create ~reserved_dst:[] () in
  fun name ->
    let preferred_name = remove_leading_underscores name |> normalize_name in
    Protect_ident.add_translation map name ~preferred_dst:preferred_name

let simplify_rule_body translate_name =
  let rec simplify (x : rule_body) : rule_body =
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
        let name =
          if alias.named then
            translate_name alias.value
          else
            alias.value
        in
        let content = simplify alias.content in
        if alias.must_be_preserved then
          ALIAS { alias with value = name; content }
        else
          content
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

   We don't mind those extra nodes in the parse tree, but we must perform
   this inlining to avoid conflicts in the grammar. This is why we must
   perform this inline here.
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

  let get_inlined_body name =
    Hashtbl.find_opt inline_rules name in

  (* parents = stack of rule names being inlined, used to detect cycles. *)
  let rec inline parents (x : rule_body) : rule_body =
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
        (* remove aliases other than those introduced automatically *)
        let content = inline parents alias.content in
        if alias.must_be_preserved then
          ALIAS { alias with content }
        else
          content
    | FIELD (field_name, x) -> FIELD (field_name, inline parents x)
    | IMMEDIATE_TOKEN x -> IMMEDIATE_TOKEN (inline parents x)
    | TOKEN x -> TOKEN (inline parents x)
  in
  let inline_rules rules =
    List.map (fun (name, body) ->
      (name, inline [name] body)
    ) rules
  in
  { grammar with
    inline = [];
    rules = inline_rules grammar.rules }

let translate_named_prec_level translate_name (x : named_prec_level) =
  match x with
  | Prec_symbol name -> Prec_symbol (translate_name name)
  | Prec_string _ as x -> x

let translate_precedences translate_name ll =
  List.map (List.map (translate_named_prec_level translate_name)) ll

(* Handle extras that appear in ordinary rules.
 *
 * This addresses the issue outlined in
 * https://github.com/semgrep/ocaml-tree-sitter-core/issues/36.
 *
 * If an extra appears in an ordinary rule, it is, in the general case,
 * impossible for ocaml-tree-sitter to tell from the CST whether an extra should
 * be discarded or whether it should be incorporated into the typed CST.
 *
 * This addresses that ambiguity by aliasing all extras that appear in other
 * rules so that they appear with a different name. This way, we can distinguish
 * between ordinary extras and those that are part of the tree: ordinary extras
 * will have the original name, and important extras will have the new, aliased
 * name.
*)
let alias_extras grammar =
  let is_extra =
    let table =
      grammar.extras
      |> List.to_seq
      |> Seq.filter_map (function
        | SYMBOL name -> Some name
        | _ -> None)
      |> Seq.map (fun name -> (name, ()))
      |> Hashtbl.of_seq
    in
    fun x -> Hashtbl.mem table x
  in
  let fresh =
    let used_rule_names =
      grammar.rules
      |> List.map (fun (name, _) -> name)
    in
    match Fresh.init_scope used_rule_names with
    | Ok scope -> scope
    | Error rules ->
        let rules = String.concat ", " rules in
        failwith ("Unexpected duplicate rules: " ^ rules)
  in
  let new_aliases = ref [] in
  let aliased_rules = ref [] in
  let rec insert_aliases (x : rule_body) : rule_body =
    match x with
    | SYMBOL name -> (
        if is_extra name then
          let new_name = Fresh.create_name fresh (name ^ "_explicit") in
          new_aliases := new_name :: !new_aliases;
          aliased_rules := name :: !aliased_rules;
          ALIAS {
            value=new_name;
            named=true;
            content=SYMBOL name;
            must_be_preserved=true;
          }
        else x)
    (* Cases below only traverse the structure. We could cut down on
       boilerplate by using deriving visitors on this data
       structure. *)
    | STRING _
    | PATTERN _
    | BLANK -> x
    | REPEAT x -> REPEAT (insert_aliases x)
    | REPEAT1 x -> REPEAT1 (insert_aliases x)
    | CHOICE xs -> CHOICE (List.map insert_aliases xs)
    | SEQ xs -> SEQ (List.map insert_aliases xs)
    | PREC (prec, x) -> PREC (prec, insert_aliases x)
    | PREC_DYNAMIC (prec, x) -> PREC_DYNAMIC (prec, insert_aliases x)
    | PREC_LEFT (prec, x) -> PREC_LEFT (prec, insert_aliases x)
    | PREC_RIGHT (prec, x) -> PREC_RIGHT (prec, insert_aliases x)
    | ALIAS alias ->
        let content = insert_aliases alias.content in
        ALIAS { alias with content }
    | FIELD (field_name, x) -> FIELD (field_name, insert_aliases x)
    | IMMEDIATE_TOKEN x -> IMMEDIATE_TOKEN (insert_aliases x)
    | TOKEN x -> TOKEN (insert_aliases x)
  in
  let rules =
    List.map (fun (id, body) -> (id, insert_aliases body)) grammar.rules in
  (* Later in the pipeline, ocaml-tree-sitter-core checks that each
     name used in an alias is associated with an actual rule. I
     (nmote) suspect that this isn't necessary, but for now we'll
     insert a blank rule for each new alias to satisfy this check.
  *)
  let new_alias_rules = List.map (fun name -> name, BLANK) !new_aliases in
  let rules = rules @ new_alias_rules in
  let rules =
    (* Hack to work around https://github.com/tree-sitter/tree-sitter/issues/1834.
       Insert an unused rule that simply references each extra. This keeps
       tree-sitter from renaming all instances of the extra based on the alias,
       since it only creates a default alias if a rule appears only in aliases
       (see https://github.com/tree-sitter/tree-sitter/pull/1836)
    *)
    let dummy_rules =
      List.mapi
        (fun i extra_name ->
           let dummy_name =
             Fresh.create_name fresh ("dummy_alias" ^ (string_of_int i)) in
           let rule = SYMBOL extra_name in
           (dummy_name, rule)
        ) !aliased_rules
    in
    rules @ dummy_rules
  in
  { grammar with rules }

let simplify_grammar grammar =
  let grammar = alias_extras grammar in
  let grammar = Missing_node.work_around_missing_nodes grammar in
  let grammar = apply_inline grammar in
  let translate_name = make_name_translator () in
  let simplify = simplify_rule_body translate_name in

  (* Keep inlined rules, which we'll use for deinlining. See Deinlining.ml. *)
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
    precedences = translate_precedences translate_name grammar.precedences;
    externals = List.map simplify grammar.externals;
    supertypes = [];
    rules = simplified_rules; (* includes inlined rules on purpose *)
  }

let run grammar output_file =
  let oc = open_out output_file in
  let orig_grammar =
    Atdgen_runtime.Util.Json.from_file Tree_sitter_j.read_grammar grammar
  in
  let new_grammar = simplify_grammar orig_grammar in
  let compact_json =
    Atdgen_runtime.Util.Json.to_string Tree_sitter_j.write_grammar new_grammar
  in
  let pretty_json = Yojson.Safe.prettify compact_json in
  fprintf oc "%s\n%!" pretty_json;
  close_out oc
