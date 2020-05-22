(*
   Various reusable utilities involved in code generation.
*)

open Printf

let translate_ident =
  let registry = Protect_ident.create () in
  fun ident -> Protect_ident.translate registry ident

let interleave sep l =
  let rec loop = function
    | [] -> []
    | x :: xs -> sep :: x :: loop xs
  in
  match l with
  | x :: xs -> x :: loop xs
  | [] -> []

(* Like List.fold_right, with additional argument indicating the position
   in the list. *)
let fold_righti f xs init_acc =
  let rec fold pos = function
    | [] -> init_acc
    | x :: xs ->
        f pos x (fold (pos + 1) xs)
  in
  fold 0 xs

(* Create the list [0; 1; ...; n-1] *)
let enum n =
  Array.init n (fun i -> i) |> Array.to_list

let format_typedef pos def =
  let open Indent.Types in
  let is_first = (pos = 0) in
  let type_ =
    if is_first then
      "type"
    else
      "and"
  in
  match def with
  | Line first_line :: rest ->
      Line (sprintf "%s %s" type_ first_line) :: rest
  | _ ->
      Line type_ :: def

(* Insert the correct 'type' or 'and' from a list of OCaml
   type definitions.
   The first item must be a line without the 'type'.
*)
let format_typedefs defs =
  List.mapi format_typedef defs
  |> List.flatten

let format_binding ~is_rec ~is_local pos binding =
  let open Indent.Types in
  let is_first = (pos = 0) in
  let let_ =
    if is_first then (
      if is_rec then
        "let rec"
      else
        "let"
    )
    else (
      if is_rec then
        "and"
      else
        "let"
    )
  in
  let individual_in =
    if is_local && not is_rec then
      [Line "in"]
    else
      []
  in
  (match binding with
   | Line first_line :: rest ->
       Line (sprintf "%s %s" let_ first_line) :: rest
   | _ ->
       Line let_ :: binding
  ) @ individual_in

(* Insert the correct 'let', 'let rec', 'and', 'in' from a list of OCaml
   bindings.
   The first item must be a line without the 'let'.
*)
let format_bindings ~is_rec ~is_local bindings =
  let open Indent.Types in
  match bindings with
  | [] -> []
  | bindings ->
      let final_in =
        if is_local && is_rec then
          [Line "in"]
        else
          []
      in
      [
        Inline (List.mapi (format_binding ~is_rec ~is_local) bindings
                |> List.flatten);
        Inline final_in;
      ]

(* Tuareg-mode for emacs gets confused by comments like "*)", breaking syntax
   highlighting.
   "(*"

   This inserts a line-break after the slash.
*)
let safe_comment =
  let regexp = Str.regexp "\\*)" in
  fun s ->
    Str.global_substitute regexp (fun _ -> "*\\\n  )") s
