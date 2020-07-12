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
type matcher_token = string * matcher_token_body

(*
   The contents of a tree-sitter node, in which each sequence of 'children'
   nodes is now a tree matching the regular expression that represents
   the rule body.

   'Children' is a representation of the original "children" field from
   tree-sitter.

   'Leaf' is a representation of a node without children, i.e. a token
   in the grammar handled by tree-sitter.
*)
and matcher_token_body =
  | Children of matcher_token Matcher.capture
  | Leaf of (Loc.t * string)

(*
   The result of matching the sequence of children nodes against a regular
   expression.
*)
type capture = matcher_token Matcher.capture

(* matcher token *)
module Matcher_token = struct
  type kind = string

  type t = matcher_token

  let kind (name, _) = name

  let show_kind s = sprintf "%S" s

  let show (name, contents) =
    match contents with
    | Children _ -> name
    | Leaf (_, tok) -> Printf.sprintf "s<%S>" tok
end

module Children_matcher = Backtrack_matcher.Make (Matcher_token)

let get_loc x = Loc.({ start = x.start_pos; end_ = x.end_pos})

let get_token src x =
  Src_file.get_token src x.start_pos x.end_pos

let register_children_regexp regexps =
  let tbl = Hashtbl.create (2 * List.length regexps) in
  List.iter (fun (name, exp) -> Hashtbl.add tbl name exp) regexps;
  fun name ->
    Hashtbl.find_opt tbl name

let make_node_matcher regexps src : node -> matcher_token =
  let get_children_regexp = register_children_regexp regexps in
  let rec match_node node =
    match node.type_ with
    | "ERROR" ->
        Tree_sitter_error.fail src node
          "Source code cannot be parsed by tree-sitter."
    | name ->
        let contents =
          match get_children_regexp name with
          | None ->
              Leaf (get_loc node, get_token src node)
          | Some regexp ->
              let matched_children = List.map match_node node.children in
              let opt_capture =
                Children_matcher.match_tree regexp matched_children
              in
              match opt_capture with
              | None ->
                  let msg = sprintf "\
Tree-sitter parse tree could not be interpreted.

Cannot match children sequence against the following regular expression:
%s"
                      (Children_matcher.show_exp regexp)
                  in
                  Tree_sitter_error.fail src node msg
              | Some capture ->
                  Children capture
        in
        (name, contents)
  in
  match_node

let matcher_token capture =
  match capture with
  | Matcher.Capture.Token mt -> mt
  | _ -> assert false

let trans_token (_name, capture) : Token.t =
  match capture with
  | Leaf tok -> tok
  | _ -> assert false

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

let rec filter_nodes keep nodes =
  List.filter_map (filter_node keep) nodes

and filter_node keep node =
  if keep node then
    Some { node with children = filter_nodes keep node.children }
  else
    None

let make_keep ~blacklist =
  let tbl = Hashtbl.create 100 in
  List.iter (fun s -> Hashtbl.replace tbl s ()) blacklist;
  let keep node =
    not (Hashtbl.mem tbl node.type_)
  in
  keep

let remove_extras ~extras =
  let keep = make_keep ~blacklist:extras in
  fun root_node ->
    { root_node with children = filter_nodes keep root_node.children }
