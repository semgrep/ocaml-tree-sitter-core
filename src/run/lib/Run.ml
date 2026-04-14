(*
   Various helper functions called directly by the generated code.
*)

open Printf
open Tree_sitter_bindings.Tree_sitter_output_t

let get_loc x = Loc.({ start = x.start_pos; end_ = x.end_pos})

let get_region src x =
  Src_file.get_region src x.start_pos x.end_pos

let children (node : node) : node list =
  match node.children with
  | None -> []
  | Some l -> l

let token src (node : node) : Loc.t * string =
  (get_loc node, get_region src node)

let single (children : node list) : node =
  match children with
  | [x] -> x
  | _ ->
      failwith (
        sprintf "Run.single: expected exactly one child, got %d"
          (List.length children)
      )

let nth_opt (children : node list) (i : int) : node option =
  if i < List.length children then
    Some (List.nth children i)
  else
    None

let fail (node : node) (rule_name : string) : 'a =
  failwith (
    sprintf "Run.fail: unexpected children for rule %S at %d:%d"
      rule_name node.start_pos.row node.start_pos.column
  )

let select (children : node list) (patterns : node_kind list list)
    : int * node list =
  let matches_pattern nodes pattern =
    List.length nodes = List.length pattern
    && List.for_all2 (fun (node : node) kind ->
      match kind, node.kind with
      | Name n1, Name n2 -> String.equal n1 n2
      | Literal s1, Literal s2 -> String.equal s1 s2
      | Error, Error -> true
      | _ -> false
    ) nodes pattern
  in
  let rec try_patterns i = function
    | [] -> (-1, children)
    | pat :: rest ->
        if matches_pattern children pat then (i, children)
        else try_patterns (i + 1) rest
  in
  try_patterns 0 patterns

type error_kind = Error_node | Missing_node

(*
   Extract the ERROR and MISSING nodes from the original tree.
   This is meant for reporting errors, especially if the errors can't
   be recovered from.

   Performance: we want this to be lightweight when there's no error.
   It's ok to spend more time as soon as an error is found.
*)
let extract_error_nodes root_node =
  let rec extract ~parent acc node =
    match node.kind with
    | Error ->
        (parent, node, Error_node) :: acc
    | _ ->
        if node.is_missing then
          (parent, node, Missing_node) :: acc
        else
          match node.children with
          | None -> acc
          | Some children ->
              List.fold_left (extract ~parent:(Some node)) acc children
  in
  extract ~parent:None [] root_node
  |> List.rev

let extract_errors src root_node =
  extract_error_nodes root_node
  |> List.map (fun (parent, node, error_kind) ->
    match error_kind with
    | Error_node ->
        Tree_sitter_error.create
          Tree_sitter_error_t.Error_node src ?parent node
          "Unrecognized construct"
    | Missing_node ->
        Tree_sitter_error.create
          Tree_sitter_error_t.Missing_node src ?parent node
          ("Missing element in input code: " ^
           (match node.kind with
            | Literal s -> Printf.sprintf "%S" s
            | Name s -> s
            | Error -> "???" (* should not happen *)))
  )

(* Remove extras from the tree, leaving only nodes matching the entrypoint
   rule. *)
let rec remove_extras_from_opt_nodes ~keep_node opt_nodes =
  match opt_nodes with
  | None -> None
  | Some nodes ->
      Some (List.filter_map (remove_extras_from_node ~keep_node) nodes)

and remove_extras_from_node ~keep_node node =
  if keep_node node then
    Some {
      node with
      children = remove_extras_from_opt_nodes ~keep_node node.children
    }
  else
    None

(*
   Produce fast functions for identifying whether a node is an extra
   and whether a node should be removed to allow matching with the structure
   of the grammar. This involves removing error nodes and other extra nodes
   tree-sitter may decide to insert.
*)
let make_filters ~extras =
  let extra_tbl = Hashtbl.create 100 in
  List.iter (fun s -> Hashtbl.replace extra_tbl s ()) extras;
  let is_extra node = Hashtbl.mem extra_tbl node.type_ in
  let keep_node node =
    not (node.kind = Error)
    && not (is_extra node)
  in
  is_extra, keep_node

(*
   Remove error nodes and extra nodes, which are nodes that can appear
   anywhere in the tree.
*)
let remove_extras ~keep_node root_node =
  { root_node with
    children = remove_extras_from_opt_nodes ~keep_node root_node.children }

(* Translate extras and accumulate them into a list. *)
let scan_node_for_extras ~is_extra ~keep_node ~translate_extra node =
  let rec scan_nodes_for_extras acc opt_nodes =
    match opt_nodes with
    | None -> acc
    | Some nodes ->
        List.fold_left (scan_node_for_extras ~translate_extra) acc nodes

  and scan_node_for_extras ~translate_extra acc node =
    let acc =
      if is_extra node then
        (* We must remove the other extras from the child subtrees.
           This is inefficient if we have large, nested extras due to the
           subtree being rewritten each time we encounter an extra node.
           In practice, it should be ok. *)
        match remove_extras ~keep_node node
          |> translate_extra with
        | None -> acc
        | Some x -> x :: acc
      else
        acc
    in
    (* An extra can contain other extras, so we must recurse into the children
       regardless of whether the current node is an extra. *)
    scan_nodes_for_extras acc node.children
  in
  scan_node_for_extras ~translate_extra [] node |> List.rev

let translate ~extras ~translate_root ~translate_extra orig_root_node =
  let is_extra, keep_node = make_filters ~extras in
  let pure_root_node = remove_extras ~keep_node orig_root_node in
  let root = translate_root pure_root_node in
  let extras =
    scan_node_for_extras
      ~is_extra ~keep_node ~translate_extra orig_root_node
  in
  (root, extras)
