(*
   Regular expression matcher with path capture.

   It uses Thompson's algorithm, together with path tracking.
   Thompson's algorithm consists in creating an NFA representing the
   regular expression. Then the input string is scanned in parallel
   for all possible paths. When multiple paths hit the same state at
   the same time, they are merged, i.e. we only keep one path.
   Matching is successful if at the end of the input, there is one path
   on the accepting state. The matching path is a stack that can then be
   converted to a tree.

   Thanks to path merging, the complexity of the algorithm is O(nm),
   where n is the length of the string and m is the length of the
   regular expression.
*)

open Printf

let debug = false

module Make (Token : Matcher.Token) : Matcher.Matcher
  with type token_kind = Token.kind
   and type token = Token.t =
struct
  open Matcher.Path
  open Matcher

  type token_kind = Token.kind
  type token = Token.t
  type tokens = token list

  let show_exp = Matcher.Exp.show Token.show_kind
  let show_capture = Matcher.Capture.show Token.show
  let show_match = Matcher.show_match Token.show

  (* Local type aliases for use in type annotations *)
  type nonrec exp = token_kind exp
  type path = token Path.t
  type nonrec capture = token capture

  (* Position in the arrays of states. *)
  type state_id = int

  type transition = {
    trans_tok: token_kind option;
    trans_dst: state_id;
    pre_punct: punct list;
    post_punct: punct list;
  }

  let new_trans
      ?(trans_tok = None)
      ?(pre_punct = [])
      ?(post_punct = [])
      trans_dst =
    {
      trans_tok;
      trans_dst;
      pre_punct;
      post_punct;
    }

  type state = {
    id: state_id;
    transitions: (token_kind option * path * state_id) list;
    mutable selected_path : path option;
    mutable merged_paths : path list;
  }

  type nfa = {
    input: token list;
    mutable pos: int;
    states: state array;
  }

  let reset _nfa =
    ignore (failwith "not implemented")

  let compile (_exp : exp) : nfa =
    failwith "not implemented"
(*
  let compile (exp : exp) : nfa =
    let new_id =
      let counter = ref (-1) in
      fun () ->
        incr counter;
        !counter
    in
    let new_state id transitions =
      {
        id;
        transitions;
        selected_path = None;
        merged_paths = [];
      }
    in
    (* Create the states linking src_id to dst_id and representing the paths
       through exp.
       Return the initial transitions from src_id. *)
    let rec init_states acc src_id dst_id exp =
      match exp with
      | Nothing ->
          let trans = new_trans dst_id in
          (trans, acc)
      | Token tok_id ->
          let trans = new_trans ~trans_tok:tok_id dst_id in
          (trans, acc)
      | Repeat exp ->
          (* loop *)
          let trans1, acc = init_states acc src_id src_id exp in
          (* break loop *)
          let trans2, acc = (None, dst_id) in
          let trans = trans1 @ trans2 in
          let acc = src :: acc in
          (trans, acc)
      | Alt cases ->
          let cases = List.mapi (fun i exp -> (i, exp)) cases in
          List.fold_left (fun (trans_acc, state_acc) (i, exp) ->
            let trans, acc = init_states acc src_id dst_id exp in
            (trans @ trans_acc, acc)
          ) [] cases
      | Seq (exp :: tail) ->
          let mid_id = new_id () in
          let trans, acc = init_states acc src_id mid_id exp in
          let src_state = new_state src_id trans in
          let acc = src_state :: acc in
          init_states acc mid_id dst_id (Seq tail)
    in
    let src_id = new_id () in
    let dst_id = new_id () in
    let trans, acc = init_states acc src_id dst_id exp in
    let src_state = new_state src_id trans in
    let dst_state = new_state dst_id [] in
    let all_states = src_state :: dst_state :: acc in
    List.sort .... (* sort states, turn into array, annotate start and end *)
*)

  let match_ _nfa _tokens =
    failwith "not implemented"

  (* Match and reconstruct. *)
  let match_tree exp =
    let nfa = compile exp in
    fun tokens ->
      reset nfa;
      match match_ nfa tokens with
      | None -> None
      | Some path ->
          if debug then
            printf "path: [\n%s]\n%!" (show_path Token.show path);
          Some (Capture.reconstruct exp path)
end

module String_token = struct
  type kind = string
  type t = string
  let kind x = x
  let show_kind s = s
  let show s = s
end

module Test = Make (String_token)
