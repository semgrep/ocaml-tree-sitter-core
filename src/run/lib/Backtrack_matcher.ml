(*
   A backtracking regular expression matcher.

   It promises to be simple and fast on simple regular expressions,
   but with an exponential asymptotic cost.
*)

open Printf

module Make (Token : Matcher.Token) : Matcher.Matcher
  with type token_kind = Token.kind
   and type token = Token.t =
struct
  open Matcher

  type token_kind = Token.kind
  type token = Token.t

  let show_exp = Matcher.Exp.show Token.show_kind
  let show_capture = Matcher.Capture.show Token.show
  let show_match = Matcher.show_match Token.show

  (* Local type aliases for use in type annotations *)
  type nonrec exp = token_kind exp
  type nonrec capture = token capture

  type punct =
    | Enter_repeat
    | Enter_repeat1
    | Enter_opt
    | Enter_alt of int
    | Enter_seq
    | Leave_repeat (* also used to close repeat1 *)
    | Leave_opt
    | Leave_alt
    | Leave_seq
    | Nothing

  type path_elt =
    | Token of token
    | Punct of punct

  type path = path_elt list

  let show_path_elt path_elt =
    match path_elt with
    | Token tok -> Token.show tok
    | Punct x ->
        match x with
        | Enter_repeat -> "Enter_repeat"
        | Enter_repeat1 -> "Enter_repeat1"
        | Enter_opt -> "Enter_opt"
        | Enter_alt i -> sprintf "Enter_alt %i" i
        | Enter_seq -> "Enter_seq"
        | Leave_repeat -> "Leave_repeat"
        | Leave_opt -> "Leave_opt"
        | Leave_alt -> sprintf "Leave_alt"
        | Leave_seq -> "Leave_seq"
        | Nothing -> "Nothing"

  let show_path path =
    List.map (fun x -> sprintf "  %s\n" (show_path_elt x)) path
    |> String.concat ""

  let match_success path tokens = Some (path, tokens)

  let match_end path tokens =
    match tokens with
    | [] -> Some (path, tokens)
    | _ -> None

  let (&&&) res cont =
    match res with
    | None -> None
    | Some (path, tokens) -> cont path tokens

  let rec match_exp (path : path) (exp : exp) tokens cont =
    match exp, tokens with
    | Token kind, tok :: tokens
      when kind = Token.kind tok -> Some (Token tok :: path, tokens) &&& cont
    | Repeat exp, tokens ->
        match_repeat (Punct Enter_repeat :: path) exp tokens cont
    | Repeat1 exp, tokens ->
        match_repeat1 (Punct Enter_repeat1 :: path) exp tokens cont
    | Opt exp, tokens ->
        match_opt (Punct Enter_opt :: path) exp tokens cont
    | Alt exps, tokens -> match_cases path exps tokens cont
    | Seq exps, tokens -> match_seq (Punct Enter_seq :: path) exps tokens cont
    | Nothing, tokens -> cont (Punct Nothing :: path) tokens
    | _ -> None

  and match_repeat path exp tokens cont =
    match match_exp path exp tokens match_success with
    | Some (path, tokens) ->
        match_repeat path exp tokens cont
    | None ->
        cont (Punct Leave_repeat :: path) tokens

  and match_repeat1 path exp tokens cont =
    match match_exp path exp tokens match_success with
    | Some (path, tokens) ->
        match_repeat path exp tokens cont
    | None ->
        None

  and match_opt path exp tokens cont =
    match match_exp path exp tokens match_success with
    | Some (path, tokens) ->
        cont (Punct Leave_opt :: path) tokens
    | None ->
        cont (Punct Leave_opt :: path) tokens

  and match_cases path exps tokens cont =
    if Array.length exps = 0 then
      None
    else
      let cont path tokens =
        cont (Punct Leave_alt :: path) tokens
      in
      match_case path exps tokens cont 0

  and match_case path exps tokens cont i =
    match match_exp (Punct (Enter_alt i) :: path) exps.(i) tokens cont with
    | Some _ as res -> res
    | None ->
        let i = i + 1 in
        if i < Array.length exps then
          match_case path exps tokens cont i
        else
          None

  and match_seq path exps tokens cont =
    match exps with
    | [] -> cont (Punct Leave_seq :: path) tokens
    | exp :: exps ->
        let cont path tokens = match_seq path exps tokens cont in
        match_exp path exp tokens cont

  let rec reconstruct_capture (exp : exp) (path : path) : capture * path =
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
  and read_repeat exp path : _ list * path =
    match path with
    | Punct Leave_repeat :: path -> [], path
    | _ ->
        let head, path = reconstruct_capture exp path in
        let tail, path = read_repeat exp path in
        (head :: tail), path

  and read_option exp path : _ option * path =
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

  and read_alt exp path : _ * path =
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
     Match a regular expression against a sequence of tokens, return
     the path taken, which is a flat list of tokens and delimiters.

     Tokens must all be consumed for the match to be successful.
  *)
  let match_ exp tokens =
    match match_exp [] exp tokens match_end with
    | Some (path, tokens) ->
        assert (tokens = []);
        Some (List.rev path)
    | None ->
        None

  (*
     Construct a tree from a flat path returned by 'match_'.
  *)
  let reconstruct exp path =
    let res, path = reconstruct_capture exp path in
    assert (path = []);
    res

  (* Match and reconstruct. *)
  let match_tree exp tokens =
    match match_ exp tokens with
    | None -> None
    | Some path ->
        printf "path: [\n%s]\n%!" (show_path path);
        Some (reconstruct exp path)
end
