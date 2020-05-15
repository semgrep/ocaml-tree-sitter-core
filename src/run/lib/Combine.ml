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

let parse_seq parse_elt1 parse_tail nodes =
  match parse_elt1 nodes with
  | None -> None
  | Some (res1, nodes) ->
      match parse_tail nodes with
      | None -> None
      | Some (res2, nodes) -> Some ((res1, res2), nodes)

let parse_last parse_elt nodes =
  match parse_elt nodes with
  | Some (res1, []) -> Some (res1, [])
  | Some (_res1, _) -> None
  | None -> None

let parse_repeat parse_elt parse_tail nodes =
  let rec repeat nodes0 =
    match parse_elt nodes0 with
    | Some (elt, nodes) ->
        (* choice between extending the repeat or not *)
        (* first consider extending the repeat *)
        (match repeat nodes with
         | Some ((repeat_tail, res2), nodes) ->
             Some ((elt :: repeat_tail, res2), nodes)
         | None ->
             (* fall back to not extending the repeat *)
             (match parse_tail nodes0 with
              | None -> None
              | Some (res2, nodes) ->
                  Some (([elt], res2), nodes)
             )
        )
    | None ->
        (* no choice, can't extend the repeat *)
        match parse_tail nodes with
        | None -> None
        | Some (res2, nodes) ->
            Some (([], res2), nodes)
  in
  repeat nodes

let parse_repeat1 parse_elt parse_tail nodes =
  match parse_elt nodes with
  | None -> None
  | Some (elt, nodes) ->
      match parse_repeat parse_elt parse_tail nodes with
      | None -> None
      | Some ((repeat_tail, res2), nodes) ->
          Some ((elt :: repeat_tail, res2), nodes)

(*
   choice: (A | B | C) next
     parse_A nodes parse_tail
     || parse_B nodes parse_tail
     || parse_C nodes parse_tail
     || fail
*)
