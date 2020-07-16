(*
   As part of the simplify-grammar program, identify duplicated anonymous
   rules and give them a name.
*)

open Printf
open Tree_sitter_t

(*
   Translate a name into something else if that name is already taken.
*)
let make_name_translator rules =
  let reserved = List.map (fun (name, _rule) -> name) rules in
  let scope =
    match Fresh.init_scope reserved with
    | Ok x -> x
    | Error duplicates ->
        failwith ("Duplicate rule names: " ^ String.concat " " duplicates)
  in
  fun name ->
    Fresh.create_name scope name

let pattern_matches_empty_string pat =
  match pat with
  | "" -> true
  | _ ->
      (* FIXME: this is really a maybe. We'd have to parse the
         regexp properly and inspect it like we do for
         matches_empty_string. Since zero-length tokens aren't
         very useful, let's assume they don't exist. *)
      false

(*
   "Tree-sitter does not support syntactic rules that match the empty string
    unless they are used only as the grammar's start rule."
*)
let rec matches_empty_string node =
  match node with
  | SYMBOL _ -> false
  | STRING "" -> true
  | STRING _ -> false
  | PATTERN pat -> pattern_matches_empty_string pat
  | BLANK -> true
  | REPEAT _ -> true
  | REPEAT1 x -> matches_empty_string x
  | CHOICE xs -> List.exists matches_empty_string xs
  | SEQ xs -> List.for_all matches_empty_string xs

  | PREC (_prec, x) -> matches_empty_string x
  | PREC_DYNAMIC (_prec, x) -> matches_empty_string x
  | PREC_LEFT (_prec, x) -> matches_empty_string x
  | PREC_RIGHT (_prec, x) -> matches_empty_string x
  | ALIAS alias -> matches_empty_string alias.content
  | FIELD (_field_name, x) -> matches_empty_string x
  | IMMEDIATE_TOKEN x -> matches_empty_string x
  | TOKEN x -> matches_empty_string x

(*
   Similar function as the one found in Case_name.ml, which is what we
   use to give a name to variants based on the type of their argument.

   Here, we operate on the original grammar as parsed from 'grammar.json'
   (Tree_sitter.t) rather than on CST_grammar.t.
*)
let name_rule_body node =
  let rec mk node =
    match node with
    | SYMBOL name -> [name]
    | STRING s -> [Punct.to_alphanum s]
    | PATTERN _ -> ["pat"] (* rare or illegal *)
    | BLANK -> ["blank"] (* rare *)
    | REPEAT x -> "rep" :: mk x
    | REPEAT1 x -> "rep1" :: mk x
    | CHOICE [x; BLANK] -> "opt" :: mk x
    | CHOICE (x :: _) -> "choice" :: mk x
    | CHOICE [] -> ["nothing"] (* rare *)
    | SEQ xs -> List.map mk xs |> List.flatten

    | PREC (_prec, x) -> mk x
    | PREC_DYNAMIC (_prec, x) -> mk x
    | PREC_LEFT (_prec, x) -> mk x
    | PREC_RIGHT (_prec, x) -> mk x
    | ALIAS alias -> mk alias.content
    | FIELD (_field_name, x) -> mk x
    | IMMEDIATE_TOKEN x -> mk x
    | TOKEN x -> mk x
  in
  "anon" :: mk node
  |> String.concat "_"
  |> Abbrev.words
  |> String.lowercase_ascii (* assuming tree-sitter doesn't like uppercase
                               in rule names *)

(*
   Determine the size of a grammar node for the purpose of determinining
   if it's worth deduplicating.

   A parent's size MUST be strictly higher than the size of its child,
   so as to guarantee bottom-up scanning. (scroll down for algorithm
   description)

   'resolve' maps a node to itself or to its replacement if there's one.
*)
let compute_size resolve node =
  let rec size node =
    match node with
    | SYMBOL _ -> 0
    | STRING _ -> 0
    | PATTERN _ -> 0
    | BLANK -> 0
    | REPEAT x -> 1 + size (resolve x)
    | REPEAT1 x -> 1 + size (resolve x)
    | CHOICE xs ->
        1 + List.fold_left (fun sum x -> sum + 1 + size (resolve x)) 0 xs
    | SEQ xs ->
        1 + List.fold_left (fun sum x -> sum + size (resolve x)) 0 xs

    | PREC (_prec, x) -> 1 + size (resolve x)
    | PREC_DYNAMIC (_prec, x) -> 1 + size (resolve x)
    | PREC_LEFT (_prec, x) -> 1 + size (resolve x)
    | PREC_RIGHT (_prec, x) -> 1 + size (resolve x)
    | ALIAS alias -> 1 + size (resolve alias.content)
    | FIELD (_field_name, x) -> 1 + size (resolve x)
    | IMMEDIATE_TOKEN x -> 1 + size (resolve x)
    | TOKEN _ -> 0 (* may not contain symbols (rule names) *)
  in
  size (resolve node)

let compute_original_size node =
  compute_size (fun x -> x) node

let recompute_size replaced_nodes node =
  let resolve node =
    match Hashtbl.find_opt replaced_nodes node with
    | Some name -> SYMBOL name
    | None -> node
  in
  compute_size resolve node

let sort_candidates ~min_size orig_rules =
  let node_counts = Hashtbl.create 100 in
  let rec add node =
    let count =
      match Hashtbl.find_opt node_counts node with
      | None -> 0
      | Some n -> n
    in
    Hashtbl.replace node_counts node (count + 1);
    match node with
    | SYMBOL _
    | STRING _
    | PATTERN _
    | BLANK -> ()
    | REPEAT x
    | REPEAT1 x -> add x
    | CHOICE xs -> List.iter add xs
    | SEQ xs -> List.iter add xs

    | PREC (_prec, x) -> add x
    | PREC_DYNAMIC (_prec, x) -> add x
    | PREC_LEFT (_prec, x) -> add x
    | PREC_RIGHT (_prec, x) -> add x
    | ALIAS alias -> add alias.content
    | FIELD (_field_name, x) -> add x
    | IMMEDIATE_TOKEN x -> add x
    | TOKEN _x ->
        (* children may not contain symbols *)
        ()
  in
  List.iter (fun (_name, body) -> add body) orig_rules;

  let candidates =
    Hashtbl.fold (fun body count acc ->
      if count >= 2 then
        let size = compute_original_size body in
        if size >= min_size && not (matches_empty_string body) then
          (size, body) :: acc
        else
          acc
      else
        acc
    ) node_counts []
  in
  List.sort ((fun (a, _) (b, _) -> compare (a : int) b)) candidates

let replace_nodes node_names root_node =
  let rec replace node =
    match Hashtbl.find_opt node_names node with
    | Some name when node != root_node -> SYMBOL name
    | _ ->
        match node with
        | SYMBOL _
        | STRING _
        | PATTERN _
        | BLANK -> node
        | REPEAT x -> REPEAT (replace x)
        | REPEAT1 x -> REPEAT1 (replace x)
        | CHOICE xs -> CHOICE (List.map replace xs)
        | SEQ xs -> SEQ (List.map replace xs)

        | PREC (prec, x) -> PREC (prec, replace x)
        | PREC_DYNAMIC (prec, x) -> PREC_DYNAMIC (prec, replace x)
        | PREC_LEFT (prec, x) -> PREC_LEFT (prec, replace x)
        | PREC_RIGHT (prec, x) -> PREC_RIGHT (prec, replace x)
        | ALIAS alias -> ALIAS { alias with content = replace alias.content }
        | FIELD (field_name, x) -> FIELD (field_name, replace x)
        | IMMEDIATE_TOKEN x -> IMMEDIATE_TOKEN (replace x)
        | TOKEN _ -> node
  in
  replace root_node

(*
   Sort rules according to the order of the original rules, followed by
   the newly-introduced rules.
*)
let sort_rules orig_rules rules =
  let tbl = Hashtbl.create 100 in
  List.iteri (fun i (name, _) ->
    Hashtbl.add tbl name i
  ) orig_rules;
  let with_keys =
    List.map (fun (name, rule) ->
      let key =
        let i =
          try Hashtbl.find tbl name
          with Not_found -> max_int
        in
        (i, name)
      in
      (key, (name, rule))
    ) rules
  in
  let cmp ((i, a), _) ((j, b), _) =
    let c = compare i j in
    if c <> 0 then c
    else String.compare a b
  in
  List.sort cmp with_keys
  |> List.map snd

(*
   1. Group identical nodes in a table, count members in each group.
   2. Sort all nodes by increasing size, ensuring that we can iterate
      in a bottom-up order, such that if B is a descendant of A, B
      is handled first.
   3. Iterate over the nodes, bottom-up. Any duplicate nodes of sufficient
      size is assigned a name and registered as a new named rule.
      Computing the size of a node takes into account substitutions in
      descendant nodes.
   4. Perform top-down substitutions of all the bodies of the named rules,
      including old and new rules.
*)
let deduplicate_nodes ?(min_size = 4) orig_rules =
  let make_name_unique = make_name_translator orig_rules in
  let cur_rules = Hashtbl.create 100 in
  List.iter (fun (name, node) ->
    if Hashtbl.mem cur_rules name then
      invalid_arg
        (sprintf "Factorize_grammar.deduplicate: duplicate rule named %S"
           name);
    Hashtbl.add cur_rules name node;
  ) orig_rules;
  let sorted_candidates = sort_candidates ~min_size orig_rules in
  let node_names = Hashtbl.create 100 in
  let new_rules = Hashtbl.create 100 in
  List.iter (fun (name, node) ->
    Hashtbl.add node_names node name;
    Hashtbl.add new_rules name node
  ) orig_rules;
  List.iter (fun (_orig_size, node) ->
    let size = recompute_size node_names node in
    if size >= min_size
    && not (Hashtbl.mem node_names node)
    && not (matches_empty_string node)
    then
      let name = name_rule_body node |> make_name_unique in
      assert (not (Hashtbl.mem new_rules name));
      Hashtbl.add node_names node name;
      Hashtbl.add new_rules name node
    else
      ()
  ) sorted_candidates;
  let all_rules =
    Hashtbl.fold (fun name node acc -> (name, node) :: acc) new_rules []
  in
  List.map (fun (name, orig_node) ->
    (name, replace_nodes node_names orig_node)
  ) all_rules
  |> sort_rules orig_rules
