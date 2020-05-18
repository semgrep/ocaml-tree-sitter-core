(*
   Generic functions for combining parsers
*)

(* Type definitions for the input tree. See Tree_sitter_output.atd. *)
open Tree_sitter_output_t

type 'a reader = node list -> ('a * node list) option

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

let parse_last parse_elt nodes =
  match parse_elt nodes with
  | Some (res1, []) -> Some (res1, [])
  | Some (_res1, _) -> None
  | None -> None

(* Repeat with backtracking, starting from longest match.
   We could disable some or all backtracking here.
*)
let parse_repeat parse_elt parse_tail nodes =
  let rec find_longest_match stack nodes =
    match parse_elt nodes with
    | None -> stack
    | Some (elt, remaining_nodes) ->
        find_longest_match ((elt, remaining_nodes) :: stack) remaining_nodes
  in
  let extract_list stack =
    List.rev_map fst stack
  in
  let rec backtrack stack =
    match stack with
    | [] -> None
    | (_elt, nodes) :: remaining_stack ->
        match parse_tail nodes with
        | Some (tail, nodes) ->
            let res = (extract_list stack, tail) in
            Some (res, nodes)
        | None ->
            backtrack remaining_stack
  in
  let matches = find_longest_match [] nodes in
  backtrack matches

let parse_repeat1 parse_elt parse_tail nodes =
  match parse_elt nodes with
  | None -> None
  | Some (elt, nodes) ->
      match parse_repeat parse_elt parse_tail nodes with
      | None -> None
      | Some ((repeat_tail, res2), nodes) ->
          Some ((elt :: repeat_tail, res2), nodes)

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
