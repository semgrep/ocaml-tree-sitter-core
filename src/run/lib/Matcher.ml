(*
   Types shared by the matcher implementations.
*)

open Printf
open Tree_sitter_gen.Indent.Types

module Exp = struct
  (*
     A regular expression.
  *)
  type 'token_kind t =
    | Token of 'token_kind
    | Repeat of 'token_kind t
    | Repeat1 of 'token_kind t
    | Opt of 'token_kind t
    | Alt of 'token_kind t array
    | Seq of 'token_kind t list
    | Nothing

  let show show_token_kind x =
    let rec show (x : _ t) =
      match x with
      | Token tok -> [Line (sprintf "Token %s" (show_token_kind tok))]
      | Repeat x ->
          [
            Line "Repeat (";
            Block (show x);
            Line ")"
          ]
      | Repeat1 x ->
          [
            Line "Repeat1 (";
            Block (show x);
            Line ")"
          ]
      | Opt x ->
          [
            Line "Opt (";
            Block (show x);
            Line ")";
          ]
      | Alt cases ->
          let cases =
            Array.mapi (fun i x ->
              Inline [
                Line (sprintf "%i:" i);
                Block (show x)
              ]
            ) cases
            |> Array.to_list
          in
          [
            Line (sprintf "Alt (");
            Block cases;
            Line ")";
          ]
      | Seq l ->
          [
            Line "Seq (";
            Block (List.map show l |> List.flatten);
            Line ")";
          ]
      | Nothing ->
          [ Line "Nothing" ]
    in
    Tree_sitter_gen.Indent.to_string (show x)

end

(* A flat capture, optionally used by a matcher. *)
module Path = struct
  type punct =
    | Enter_repeat
    | Enter_repeat1
    | Enter_opt
    | Enter_alt of int
    | Enter_seq
    | Leave_repeat
    | Leave_repeat1
    | Leave_opt
    | Leave_alt
    | Leave_seq
    | Nothing

  type 'token elt =
    | Token of 'token
    | Punct of punct

  (* A sequence of captured elements meant to be reconstructed into
     a tree to form a proper capture using Capture.reconstruct. *)
  type 'token t = 'token elt list

  let show_path_elt show_token path_elt =
    match path_elt with
    | Token tok -> show_token tok
    | Punct x ->
        match x with
        | Enter_repeat -> "Enter_repeat"
        | Enter_repeat1 -> "Enter_repeat1"
        | Enter_opt -> "Enter_opt"
        | Enter_alt i -> sprintf "Enter_alt %i" i
        | Enter_seq -> "Enter_seq"
        | Leave_repeat -> "Leave_repeat"
        | Leave_repeat1 -> "Leave_repeat1"
        | Leave_opt -> "Leave_opt"
        | Leave_alt -> sprintf "Leave_alt"
        | Leave_seq -> "Leave_seq"
        | Nothing -> "Nothing"

  let show_path show_token path =
    List.map (fun x -> sprintf "  %s\n" (show_path_elt show_token x)) path
    |> String.concat ""

end

module Capture = struct
  open Path

  (*
     A list of tokens successfully matched against a regular expression.
  *)
  type 'token t =
    | Token of 'token
    | Repeat of 'token t list
    | Repeat1 of 'token t list
    | Opt of 'token t option
    | Alt of int * 'token t
    | Seq of 'token t list
    | Nothing

  let show show_token capture =
    let rec show (capture : _ t) =
      match capture with
      | Token tok -> [Line (sprintf "Token %s" (show_token tok))]
      | Repeat l ->
          [
            Line "Repeat [";
            Block (List.map show l |> List.flatten);
            Line "]"
          ]
      | Repeat1 l ->
          [
            Line "Repeat1 [";
            Block (List.map show l |> List.flatten);
            Line "]"
          ]
      | Opt None ->
          [ Line "None" ]
      | Opt (Some x) ->
          [
            Line "Some (";
            Block (show x);
            Line ")";
          ]
      | Alt (i, x) ->
          [
            Line (sprintf "Alt %i (" i);
            Block (show x);
            Line ")";
          ]
      | Seq l ->
          [
            Line "Seq (";
            Block (List.map show l |> List.flatten);
            Line ")";
          ]
      | Nothing ->
          [ Line "Nothing" ]
    in
    Tree_sitter_gen.Indent.to_string (show capture)

  let rec reconstruct_capture
      (exp : _ Exp.t) (path : _ Path.t) : _ t * _ Path.t =
    match exp, path with
    | Token _, (Token tok :: path) -> Token tok, path
    | Repeat exp, (Punct Enter_repeat :: path) ->
        let list, path = read_repeat exp path in
        Repeat list, path
    | Repeat1 exp, (Punct Enter_repeat1 :: path) ->
        let list, path = read_repeat exp path in
        Repeat1 list, path
    | Opt exp, (Punct Enter_opt :: path) ->
        let option, path = read_option exp path in
        Opt option, path
    | Alt cases, (Punct (Enter_alt i) :: path) ->
        let res, path = read_alt cases.(i) path in
        Alt (i, res), path
    | Seq exps, (Punct Enter_seq :: path) ->
        let list, path = read_seq exps path in
        Seq list, path
    | Nothing, (Punct Nothing :: path) ->
        Nothing, path
    | _ ->
        assert false

  (* used for both repeat and repeat1 *)
  and read_repeat exp path : _ list * _ Path.t =
    match path with
    | Punct (Leave_repeat | Leave_repeat1) :: path -> [], path
    | _ ->
        let head, path = reconstruct_capture exp path in
        let tail, path = read_repeat exp path in
        (head :: tail), path

  and read_option exp path : _ option * _ Path.t =
    match path with
    | Punct Leave_opt :: path -> None, path
    | _ ->
        let elt, path = reconstruct_capture exp path in
        let path =
          match path with
          | Punct Leave_opt :: path -> path
          | _ -> assert false
        in
        Some elt, path

  and read_alt exp path : _ * _ Path.t =
    let elt, path = reconstruct_capture exp path in
    match path with
    | Punct Leave_alt :: path -> elt, path
    | _ -> assert false

  and read_seq exps path =
    match exps with
    | [] ->
        let path =
          match path with
          | Punct Leave_seq :: path -> path
          | _ -> assert false
        in
        [], path
    | exp :: exps ->
        let head, path = reconstruct_capture exp path in
        let tail, path = read_seq exps path in
        (head :: tail), path

  (*
     Construct a tree from a flat path returned by a matcher.
  *)
  let reconstruct exp path =
    let res, path = reconstruct_capture exp path in
    match path with
    | [] -> res
    | _ -> invalid_arg "Matcher.Capture.reconstruct: malformed flat capture"
end

type 'token_kind exp = 'token_kind Exp.t
type 'token capture = 'token Capture.t

(* An element of the input sequence. *)
module type Token = sig
  (* The token kind, known in advance and comparable. *)
  type kind

  (* A captured token. *)
  type t

  (* Get the token kind. *)
  val kind : t -> kind

  (* Produce a human-readable view of the token kind. *)
  val show_kind : kind -> string

  (* Produce a human-readable view of the token. *)
  val show : t -> string
end

module type Matcher = sig
  type token_kind
  type token

  val show_exp : token_kind exp -> string
  val match_tree : token_kind exp -> token list -> token capture option
  val show_capture : token capture -> string
  val show_match : token capture option -> string
end

let show_match show_token opt_capture =
  match opt_capture with
  | None -> "[no match]"
  | Some capture -> Capture.show show_token capture
