(*
   Various helper functions called directly by the generated code.
*)

open Printf
open Tree_sitter_bindings.Tree_sitter_output_t

(*
   A translated node from the original parse tree from tree-sitter.

   The node 'type', which is a rule name (e.g. "expression")
   or a literal symbol (e.g. "+"), is paired with some contents translated
   from the original tree-sitter parse tree. Examples:

     ("expression", Children ...)

     ("+", Leaf (..., "+"))

   This is a token for the regular expression matcher, hence the name
   'matcher_token'. It is not in general a token wrt the tree-sitter
   grammar.
*)
type matcher_token = node_kind * matcher_token_body

(*
   The contents of a tree-sitter node, in which each sequence of 'children'
   nodes is now a tree matching the regular expression that represents
   the rule body.

   'Children' is a representation of the original "children" field from
   tree-sitter.

   'Leaf' is a representation of a node without children, i.e. a token
   in the grammar handled by tree-sitter. It is also used to represent
   error nodes which may have children that were discarded because we
   don't know how to interpret them.
*)
and matcher_token_body =
  | Children of matcher_token Matcher.capture
  | Leaf of (Loc.t * string)

type exp = node_kind Matcher.exp

(*
   The result of matching the sequence of children nodes against a regular
   expression.
*)
type capture = matcher_token Matcher.capture

(* matcher token *)
module Matcher_token = struct
  type kind = node_kind

  type t = matcher_token

  let kind (kind, _) = kind

  let show_kind = function
    | Name s -> sprintf "name:%S" s
    | Literal s -> sprintf "literal:%S" s
    | Error -> "error"

  let show (kind, contents) =
    match contents with
    | Children _ -> show_kind kind
    | Leaf (_, tok) -> Printf.sprintf "%s<%S>" (show_kind kind) tok
end

module Children_matcher = Backtrack_matcher.Make (Matcher_token)

let get_loc x = Loc.({ start = x.start_pos; end_ = x.end_pos})

let get_region src x =
  Src_file.get_region src x.start_pos x.end_pos

let register_children_regexp regexps =
  let tbl = Hashtbl.create (2 * List.length regexps) in
  List.iter (fun (name, exp) -> Hashtbl.add tbl name exp) regexps;
  fun name ->
    Hashtbl.find_opt tbl name

let make_node_matcher regexps src : node -> matcher_token =
  let get_children_regexp = register_children_regexp regexps in
  let rec match_node node =
    let kind = node.kind in
    match kind, node.children with
    | Error, _ ->
        (* may happen if error nodes weren't filtered out *)
        Error, Leaf (get_loc node, get_region src node)
    | Literal _, None ->
        kind, Leaf (get_loc node, get_region src node)
    | Name name, Some children ->
        (match get_children_regexp name with
         | Some None ->
             (* don't care if there are any children *)
             kind, Leaf (get_loc node, get_region src node)
         | Some (Some regexp) ->
             let matched_children = List.map match_node children in
             let opt_capture =
               Children_matcher.match_tree regexp matched_children
             in
             (match opt_capture with
              | None ->
                  Error, Leaf (get_loc node, get_region src node)
              | Some capture ->
                  kind, Children capture
             )
         | _ ->
             let msg = sprintf "\
Wrong node type: confusion between named node %s and literal %S?

Tree-sitter parse tree could not be interpreted.
"
                 name name
             in
             Tree_sitter_error.internal_error src node msg
        )
    | _ -> assert false
  in
  match_node

let matcher_token capture =
  match capture with
  | Matcher.Capture.Token mt -> mt
  | _ -> assert false

let trans_token (_name, capture) : Token.t =
  match capture with
  | Leaf tok -> tok
  | Children capture ->
      printf "Got Children instead of Leaf:\n%s\n%!"
        (Children_matcher.show_capture capture);
      assert false

let repeat map capture =
  match capture with
  | Matcher.Capture.Repeat l -> List.map map l
  | _ -> assert false

let repeat1 map capture =
  match capture with
  | Matcher.Capture.Repeat1 l -> List.map map l
  | _ -> assert false

let opt map capture =
  match capture with
  | Matcher.Capture.Opt l -> Option.map map l
  | _ -> assert false

let nothing capture =
  match capture with
  | Matcher.Capture.Nothing -> ()
  | _ -> assert false

(*
   Extract the error nodes from the original tree.
   This is meant for reporting errors, especially if the errors can't
   be recovered from.
*)
let extract_errors root_node =
  let rec extract acc node =
    match node.kind with
    | Error -> (node :: acc)
    | _ ->
        match node.children with
        | None -> acc
        | Some children -> List.fold_left extract acc children
  in
  extract [] root_node
  |> List.rev

let check_matched_tree src root_node matched_tree =
  match matched_tree with
  | (Error, _) ->
      let errors = extract_errors root_node in
      (match errors with
       | [] ->
           Tree_sitter_error.internal_error src root_node
             "Cannot interpret tree-sitter output"
       | first_error_node :: _ ->
           Tree_sitter_error.external_error src first_error_node
             "Unrecoverable parse error"
      )
  | _ -> ()

let rec filter_nodes keep nodes =
  List.filter_map (filter_node keep) nodes

and filter_node keep node =
  if keep node then
    Some { node with children = Option.map (filter_nodes keep) node.children }
  else
    None

let make_keep ~blacklist =
  let tbl = Hashtbl.create 100 in
  List.iter (fun s -> Hashtbl.replace tbl s ()) blacklist;
  let keep node =
    not (node.kind = Error)
    && not (Hashtbl.mem tbl node.type_)
  in
  keep

(*
   Remove error nodes and extra nodes, which are nodes that can appear
   anywhere in the tree.
*)
let remove_extras ~extras =
  let keep = make_keep ~blacklist:extras in
  fun root_node ->
    { root_node with
      children = Option.map (filter_nodes keep) root_node.children }
