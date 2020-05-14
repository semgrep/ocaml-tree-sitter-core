(*
   Various functions used by generated parsers.
*)

(* Type definitions for the input tree. See Tree_sitter_output.atd. *)
open Tree_sitter_output_t

type 'a wrapped_result = 'a option * node list
type 'a unwrapped_result = 'a * node list

type 'a reader = node list -> 'a wrapped_result

let rec parse_repeat: 'a reader -> 'a list reader = fun f xs ->
  match f xs with
  | Some e, xs ->
      (match parse_repeat f xs with
       | Some es, xs -> Some (e :: es), xs
       | None, _ -> assert false
      )
  | None, xs -> Some [], xs

let parse_repeat1 : 'a reader -> 'a list reader = fun f xs ->
  match f xs with
  | Some e, xs ->
      (match parse_repeat f xs with
       | Some es, xs -> Some (e :: es), xs
       | None, _ -> assert false
      )
  | None, xs -> None, xs

let rec parse_choice: 'a reader list -> 'a reader = fun fs xs ->
  match fs with
  | [] -> None, xs
  | f :: fs ->
      (match f xs with
       | Some _, _ as res -> res
       | None, xs -> parse_choice fs xs
      )

(* Meant to be aliased to (>>=) in generated code. *)
let parse_seq res_parser1 parser2_closure =
  match res_parser1 with
  | None, xs -> None, xs
  | Some e, xs -> parser2_closure (e, xs)
