(*
   Model code that matches regular expressions and captures the matched
   elements.
*)

open Printf

(* Code generation details *)
module Param = struct
  open Indent.Types

  type code = Indent.t

  let code s =
    [Line s]

  let parse_fail =
    [Line "fun _nodes -> None"]

  let apply_variant name arg =
    [Line (sprintf "`%s %s" name arg)]
end

type repeat_kind =
  | One
  | Optional
  | Repeat
  | Repeat1

(* Representation of the regular expression to match. *)
type seq_parser =
  | Parse_elt of Param.code
  | Parse_inline of seq_parser
  | Parse_repeat of repeat_kind * Param.code * seq_parser
  | Parse_choice of (string * seq_parser) list * seq_parser

(* Generic code representation resulting from the compilation.
   It's meant to be easy to convert to actual code. *)
type exp =
  | Atom of Param.code
  | App of exp * exp
  | Fun of string * exp
  | Def of string * exp * exp
  | Op of repeat_kind * exp * exp
  | Alt of exp * exp
  | Flatten of exp * int * (string -> Param.code)
               (* value to match,
                  number of elements captured as nested pairs when successful,
                  wrapper for the flattened tuple *)

let atom s = Atom (Param.code s)

(*
   The main function that turns a regexp into a match-and-capture algorithm.
*)
let rec compile seq_parser : int * exp =
  match seq_parser with
  | Parse_elt comp -> 1, Atom comp
  | Parse_inline seq_parser ->
      let n, f = compile seq_parser in
      let nested_result = App (App (f, atom "_parse_tail"), atom "nodes") in
      (2,
       Fun ("_parse_tail",
            Flatten (nested_result, n, Param.code)))
  | Parse_repeat (repeat_kind, parse_elt, parse_tail) ->
      let n, f = compile parse_tail in
      (n + 1,
       Op (repeat_kind, Atom parse_elt, f))
  | Parse_choice (cases, parse_tail) ->
      let n, f = compile parse_tail in
      (n + 1,
       Def ("_parse_tail", f, compile_choice cases))

and compile_choice cases =
  match cases with
  | [] ->
      App (Atom Param.parse_fail, atom "nodes")
  | (name, seq_parser) :: cases ->
      let n, f = compile seq_parser in
      let nested_result = App (App (f, atom "_parse_tail"), atom "nodes") in
      let wrap arg = Param.apply_variant name arg in
      let first = Flatten (nested_result, n, wrap) in
      match cases with
      | [] -> first
      | cases -> Alt (first, compile_choice cases)
