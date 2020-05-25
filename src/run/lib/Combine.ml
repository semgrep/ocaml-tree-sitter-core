(*
   Generic functions for combining parsers
*)

open Printf

(* Type definitions for the input tree. See Tree_sitter_output.atd. *)
open Tree_sitter_output_t

type 'a reader = node list -> ('a * node list) option
type 'a children_reader = node list -> 'a option

type ('head_elt, 'head, 'tail) seq_reader =
  'head_elt reader -> 'tail reader -> ('head * 'tail) reader

let trace_indent = ref 0

let show_node node =
  node.type_

let show_nodes nodes =
  match nodes with
  | [] -> "[]"
  | [node] -> sprintf "[%s]" (show_node node)
  | node :: _ -> sprintf "[%s ...]" (show_node node)

let make_indent n =
  String.init n (fun i ->
    if i mod 4 = 0 then
      '|'
    else
      ' '
  )

let trace name f nodes =
  let indent = make_indent !trace_indent in
  printf "%s%s <- %s\n" indent name (show_nodes nodes);
  trace_indent := !trace_indent + 2;
  let res = f nodes in
  trace_indent := !trace_indent - 2;
  printf "%s%s -> %s\n"
    indent name (if res = None then "fail" else "OK");
  res

let parse_rule type_ parse_children : 'a reader = fun nodes ->
  match nodes with
  | [] -> None
  | node :: nodes ->
      if node.type_ = type_ then
        match parse_children node.children with
        | Some res -> Some (res, nodes)
        | None -> None
      else
        None

let parse_fail: 'a reader = fun _nodes -> None
let parse_success : 'a reader = fun nodes -> Some ((), nodes)

let parse_node : (node -> 'a option) -> 'a reader = fun f nodes ->
  match nodes with
  | x :: nodes ->
      (match f x with
       | Some e -> Some (e, nodes)
       | None -> None
      )
  | [] -> None

let parse_root parse_elt node =
  match parse_elt [node] with
  | None -> None
  | Some (res, _nodes) -> Some res

let parse_seq parse_elt1 parse_tail nodes =
  match parse_elt1 nodes with
  | None -> None
  | Some (res1, nodes) ->
      match parse_tail nodes with
      | None -> None
      | Some (res2, nodes) -> Some ((res1, res2), nodes)

let parse_end nodes =
  match nodes with
  | [] -> Some ((), [])
  | _ -> None

let parse_full parse_elt nodes =
  match parse_seq parse_elt parse_end nodes with
  | Some ((res, ()), []) -> Some res
  | Some (_, _::_)
  | None -> None

(* Each time we make forward progress in a repeat, we take a snapshot
   of the progress at this point: captured elements so far and remaining input
   nodes.
*)
let push elt remaining_nodes stack =
  let stack_elt =
    match stack with
    | (prev_elts, _) :: _ -> (elt :: prev_elts, remaining_nodes)
    | [] -> assert false
  in
  stack_elt :: stack

let rec find_longest_match parse_elt stack nodes =
  match parse_elt nodes with
  | None -> stack
  | Some (elt, remaining_nodes) ->
      let stack = push elt remaining_nodes stack in
      if remaining_nodes == nodes (* physical equality *) then
        (* nothing was consumed, return just one element instead of looping
           forever. *)
        stack
      else
        find_longest_match parse_elt stack remaining_nodes

(* Repeat with backtracking, starting from longest match.
   We could disable some or all backtracking here.
*)
let parse_repeat parse_elt parse_tail nodes =
  let rec backtrack stack =
    match stack with
    | [] -> None
    | (rev_elts, nodes) :: remaining_stack ->
        match parse_tail nodes with
        | Some (tail, nodes) ->
            let res = (List.rev rev_elts, tail) in
            Some (res, nodes)
        | None ->
            backtrack remaining_stack
  in
  let first_snapshot = ([], nodes) in
  let matches = find_longest_match parse_elt [first_snapshot] nodes in
  backtrack matches

let parse_repeat1 parse_elt parse_tail nodes =
  match parse_elt nodes with
  | None -> None
  | Some (elt, nodes) ->
      match parse_repeat parse_elt parse_tail nodes with
      | None -> None
      | Some ((repeat_tail, res2), nodes) ->
          Some ((elt :: repeat_tail, res2), nodes)

let parse_optional parse_elt parse_tail nodes =
  match parse_elt nodes with
  | None ->
      (match parse_tail nodes with
       | None -> None
       | Some (tail, nodes) -> Some ((None, tail), nodes)
      )
  | Some (elt, nodes) ->
      match parse_tail nodes with
      | None -> None
      | Some (tail, nodes) -> Some ((Some elt, tail), nodes)

let map f parse_elt nodes =
  match parse_elt nodes with
  | None -> None
  | Some (elt, nodes) -> Some (f elt, nodes)

let map_fst f parse_elt nodes =
  match parse_elt nodes with
  | None -> None
  | Some ((a, b), nodes) -> Some ((f a, b), nodes)

let assign_unique_ids root_node =
  let counter = ref (-1) in
  let create_id () = incr counter; !counter in
  let rec map node =
    let id = create_id () in
    assert (id >= 0);
    let children = List.map map node.children in
    { node with id; children }
  in
  map root_node

module Node_list = struct
  type t = node list

  (* The input tree doesn't change during parsing, so it's safe to assume
     that a given node will always be the head of the same list and
     use it to identify the list. *)
  let id = function
    | [] -> -1
    | node :: _ -> node.id

  let equal a b = (id a) = (id b)
  let hash x = id x
end

module Tbl = Hashtbl.Make (Node_list)

module Memoize = struct
  type 'a t = ('a * node list) option Tbl.t
  let create () = Tbl.create 100
  let apply tbl parse nodes =
    try Tbl.find tbl nodes
    with Not_found ->
      let res = parse nodes in
      Tbl.replace tbl nodes res;
      res
end
