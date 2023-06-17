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

let make_tree_matcher regexps src : node -> matcher_token option =
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
                  (*
                     Propagate the matching error up the tree.

                     It looks like this situation doesn't happen,
                     which would imply that tree-sitter error nodes occur only
                     in optional positions ('optional' or 'repeat' constructs).

                     If it turns out this situation sometimes happens,
                     we should prevent this error from
                     bubbling up to the root, by ignoring these new error
                     nodes when matching a repeat or optional pattern.
                  *)
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
  fun root_node ->
    match match_node root_node with
    | Error, _ -> None (* error bubbled up to the root *)
    | x -> Some x

let match_tree children_regexps src root_node =
  let match_tree = make_tree_matcher children_regexps src in
  match_tree root_node

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

type error_kind = Error_node | Missing_node

(*
   Extract the error nodes from the original tree.
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
          Tree_sitter_error_t.External src ?parent node
          "Unrecognized construct"
    | Missing_node ->
        Tree_sitter_error.create
          Tree_sitter_error_t.External src ?parent node
          ("Missing element in input code: " ^
           (match node.kind with
            | Literal s -> Printf.sprintf "%S" s
            | Name s -> s
            | Error -> "???" (* should not happen *)))
  )

let rec filter_nodes keep nodes =
  List.filter_map (filter_node keep) nodes

and filter_node keep node =
  if keep node then
    Some { node with children = Option.map (filter_nodes keep) node.children }
  else
    None

let has_missing_children node =
  match node.children with
  | None -> false
  | Some children -> List.exists (fun child -> child.is_missing) children

let make_keep ~blacklist =
  let tbl = Hashtbl.create 100 in
  List.iter (fun s -> Hashtbl.replace tbl s ()) blacklist;
  let keep node =
    not (node.kind = Error)
    && not (has_missing_children node)
    && not (Hashtbl.mem tbl node.type_)
  in
  keep

(*
   Remove error nodes, missing nodes, and extra nodes.

   Error nodes indicate unexpected input and can be removed from tree
   while respecting the grammar (because the error bubbles up until
   it's an optional position such as in a repeat()).

   Missing nodes are suggested nodes that don't exist in the input.
   Removing them removes them from a tuple (seq()), making the whole parsing
   fail. Removing a minimal subtree like it's done for error nodes requires
   knowledge of the grammar (e.g. is a sequence of nodes from a repeat() or
   a seq()?) and would have to be done at the time of recovering the typed
   CST, adding complexity.
   As a cheap improvement, we remove all the siblings of the missing node
   since we know it's a seq(), and hope that the seq() was in an optional
   position and won't cause a collapse of the whole tree.

   Extra nodes are nodes that can appear anywhere in the tree such as comments.
*)
let remove_extras ~extras =
  let keep = make_keep ~blacklist:extras in
  fun root_node ->
    { root_node with
      children = Option.map (filter_nodes keep) root_node.children }
