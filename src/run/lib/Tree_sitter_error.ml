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
  substring: string;
  snippet: Snippet.t;
}

exception Error of t

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
    substring = Src_file.get_token src start_pos end_pos;
    snippet = Snippet.extract src ~start_pos ~end_pos;
  }

let fail kind src node msg =
  raise (Error (create kind src node msg))

let external_error src node msg =
  fail External src node msg

let internal_error src node msg =
  fail Internal src node msg

let string_of_file_info (src_info : Src_file.info) =
  match src_info.path with
  | Some path -> sprintf "File %s" path
  | None -> src_info.name

(* Take an error message and prepend the location information,
   in a human-readable and possibly computer-readable format (TODO check with
   emacs etc.)
*)
let to_string ?(color = false) (err : t) =
  let start = err.start_pos in
  let end_ = err.end_pos in
  let loc =
    let src_name = string_of_file_info err.file in
    if start.row = end_.row then
      sprintf "%s, line %i, characters %i-%i:"
        src_name
        (start.row + 1) start.column end_.column
    else
      sprintf "%s, line %i, character %i to line %i, character %i:"
        src_name
        (start.row + 1) start.column (end_.row + 1) end_.column
  in
  sprintf "\
%s
%s%s"
    loc
    (Snippet.format ~color err.snippet)
    err.msg
