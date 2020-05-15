(*
   Generic functions for combining parsers
*)

(* Type definitions for the input tree. See Tree_sitter_output.atd. *)
open Tree_sitter_output_t

type 'a reader = node list -> ('a * node list) option
type 'a success_reader = node list -> ('a * node list)

let parse_node: (node -> 'a option) -> 'a reader = fun f nodes ->
  match nodes with
  | x :: nodes ->
      (match f x with
       | Some e -> Some (e, nodes)
       | None -> None
      )
  | [] -> None

let parse_repeat: 'a reader -> 'a list success_reader = fun f nodes ->
  let rec repeat acc nodes =
    match f nodes with
    | Some (e, nodes) ->
        repeat (e :: acc) nodes
    | None ->
        (List.rev acc, nodes)
  in
  repeat [] nodes

let parse_repeat1 : 'a reader -> 'a list reader = fun f nodes ->
  match f nodes with
  | Some (e, nodes) ->
      let es, nodes = parse_repeat f nodes in
      Some (e :: es, nodes)
  | None ->
      None
