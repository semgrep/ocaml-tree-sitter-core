(*
   Types shared by the matcher implementations.
*)

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
end

module Capture = struct
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

  (* Produce a human-readable view of the token. *)
  val show : t -> string
end

module type Matcher = sig
  type token_kind
  type token

  val match_tree : token_kind exp -> token list -> token capture option
  val show_match : token capture option -> string
end

let show_match show_token opt_capture =
  let open Printf in
  let open Tree_sitter_gen.Indent.Types in
  let rec show (capture : _ capture) =
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
  let show_opt = function
    | None -> [Line "no match"]
    | Some capture -> show capture
  in
  Tree_sitter_gen.Indent.to_string (show_opt opt_capture)
