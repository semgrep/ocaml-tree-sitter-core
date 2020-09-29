(*
   Simple utilities to work on the types defined in Tree_sitter_output.atd.
*)

open Printf
open Tree_sitter_bindings.Tree_sitter_output_t

type kind =
  | Internal (* a bug *)
  | External (* malformed input or bug, but we don't know *)

type t = {
  kind: kind;
  msg: string;
  file: Src_file.info;
  start_pos: position;
  end_pos: position;
  snippet: string * string * string;
}

exception Error of t

(* TODO: include up to 2 lines of context before and after the error. *)
let format_snippet src start end_ =
  let snippet = Src_file.get_token src start end_ in
  "", snippet, "\n"

let string_of_node_type x =
  match x.children with
  | None ->
      sprintf "%S" x.type_
  | Some _ ->
      x.type_

let string_of_node x =
  match x.children with
  | None ->
      sprintf "node type: %S" x.type_
  | Some children ->
      sprintf "\
node type: %s
children: [
%s]"
        x.type_
        (List.map (fun x -> sprintf "  %s\n" (string_of_node_type x)) children
         |> String.concat "")

let create kind src node msg =
  let msg = sprintf "\
%s
%s"
      (string_of_node node)
      msg
  in
  let start_pos = node.start_pos in
  let end_pos = node.end_pos in
  {
    kind;
    msg;
    file = Src_file.info src;
    start_pos;
    end_pos;
    snippet = format_snippet src start_pos end_pos;
  }

let fail kind src node msg =
  raise (Error (create kind src node msg))

let external_error src node msg =
  fail External src node msg

let internal_error src node msg =
  fail Internal src node msg

let ansi_highlight s =
  match s with
  | "" -> s
  | s -> ANSITerminal.(sprintf [Bold; red] "%s" s)

let format_snippet ~color (a, b, c) =
  let b =
    if color then ansi_highlight b
    else b
  in
  a ^ b ^ c

(* Take an error message and prepend the location information,
   in a human-readable and possibly computer-readable format (TODO check with
   emacs etc.)
*)
let to_string ?(color = false) (err : t) =
  let start = err.start_pos in
  let end_ = err.end_pos in
  let loc =
    if start.row = end_.row then
      sprintf "Line %i, characters %i-%i:"
        start.row start.column end_.column
    else
      sprintf "Line %i, character %i to line %i, character %i:"
        start.row start.column end_.row end_.column
  in
  sprintf "\
%s
%s
%s"
    loc
    (format_snippet ~color err.snippet)
    err.msg
