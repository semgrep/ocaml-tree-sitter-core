(*
   "Possessive" regexp matcher.

   This is a simple pattern matcher that performs no backtracking,
   and therefore can't match arbitrary regular expressions.
*)

open Printf

type node = string
type nodes = node list

type exp =
  | Simple of string
  | End
  | Repeat of exp
  | Alt of (string * exp) * (string * exp)
  | Seq of exp * exp

type result =
  | Simple of string
  | End
  | Repeat of result list
  | Alt of (string * result)
  | Seq of (result * result)

let rec parse (exp : exp) (nodes : nodes) : (result * nodes) option =
  match exp with
  | Simple s ->
      parse_simple s nodes
  | End ->
      parse_end nodes
  | Repeat e ->
      parse_repeat e nodes
  | Alt (e1, e2) ->
      parse_alt e1 e2 nodes
  | Seq (e1, e2) ->
      parse_seq e1 e2 nodes

and parse_simple s nodes =
  match nodes with
  | s2 :: nodes when s2 = s -> Some (Simple s, nodes)
  | _ -> None

and parse_end nodes =
  match nodes with
  | [] -> Some (End, [])
  | _ -> None

and parse_repeat e nodes =
  let rec aux nodes =
    match parse e nodes with
    | None -> ([], nodes)
    | Some (res, nodes) ->
        let l, nodes = aux nodes in
        (res :: l, nodes)
  in
  let res, nodes = aux nodes in
  Some (Repeat res, nodes)

and parse_alt (name1, e1) (name2, e2) nodes =
  match parse e1 nodes with
  | Some (res, nodes) -> Some (Alt (name1, res), nodes)
  | None ->
      match parse e2 nodes with
      | Some (res, nodes) -> Some (Alt (name2, res), nodes)
      | None -> None

and parse_seq e1 e2 nodes =
  match parse e1 nodes with
  | None -> None
  | Some (res1, nodes) ->
      match parse e2 nodes with
      | None -> None
      | Some (res2, nodes) -> Some (Seq (res1, res2), nodes)

let a = "a"
let b = "b"

let string_of_nodes nodes =
  String.concat " " nodes

let string_of_output = function
  | None -> "None"
  | Some (_, nodes) -> sprintf "Some (_, %s)" (string_of_nodes nodes)

let test exp nodes expected_output =
  let output = parse exp nodes in
  printf "input:\n  %s\n%!" (string_of_nodes nodes);
  printf "expected output:\n  %s\n%!"
    (string_of_output output);
  printf "output:\n  %s\n%!"
    (string_of_output output);
  if output <> expected_output then
    printf "FAIL\n"
  else
    printf "OK\n"

(* Easy, no backtracking needed. *)

(* a *)
let () =
  test (Repeat (Simple a)) [a;a;b]
    (Some (Repeat [Simple a; Simple a], [b]))

(* a* *)
let () =
  test (Seq (Repeat (Simple a), End)) [a;a;b] None

(* a*$ *)
let () =
  test (Seq (Repeat (Simple a), End)) [a;a;]
    (Some (Seq (Repeat [Simple a; Simple a], End), []))

(* Backtracking needed, fail. *)

(* a*a *)
let () =
  test (Seq (Repeat (Simple a), Simple a)) [a;a]
    (Some (Seq (Repeat [Simple a], Simple a), []))

(* More backtracking needed, fail. *)

(* (a*a)*a *)
let () =
  test
    (
      Seq (
        Repeat (
          Seq (
            Repeat (Simple a),
            Simple a
          )
        ),
        Simple a
      )
    )
    [a;a]
    (
      Some (
        Seq (
          Repeat [
            Seq (
              Repeat [],
              Simple a
            )
          ],
          Simple a
        ),
        []
      )
    )
