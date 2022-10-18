{
  (* Only pure lists of Char are guaranteed to be parsed correctly
     by our parser. *)
  type element =
    | Char of char (* lowercased ascii *)
    | Other (* something that we couldn't parse *)

  let deduplicate xs =
    let tbl = Hashtbl.create 10 in
    List.filter (fun x ->
      if Hashtbl.mem tbl x then
        false
      else (
        Hashtbl.add tbl x ();
        true
      )
    ) xs

  let normalize_char = function
  | '-' -> '_'
  | c -> Char.lowercase_ascii c

  let lowercase_singleton_of_cset s =
    let lowercase_chars =
      String.to_seq s
      |> List.of_seq
      |> List.map normalize_char
      |> deduplicate
    in
    match lowercase_chars with
    | [] -> Other
    | [c] -> Char c
    | _ :: _ -> Other

}

rule sequence = parse
| ['a'-'z' 'A'-'Z' '0'-'9' '_' '-'] as c {
     let elt = Char (normalize_char c) in
     elt :: sequence lexbuf
   }
| '[' (['a'-'z' 'A'-'Z' '_' '-']+ as set) ']' {
     let elt = lowercase_singleton_of_cset set in
     elt :: sequence lexbuf
   }
| _ { Other :: sequence lexbuf }
| eof { [] }

{
  let string_of_list xs =
    List.map (String.make 1) xs |> String.concat ""

  let infer s =
    let lexbuf = Lexing.from_string s in
    let elements = sequence lexbuf in
    let chars =
      try Some (List.map (function Char c -> c | Other -> raise Exit) elements)
      with Exit -> None
    in
    match chars with
    | Some chars ->
        let chars = List.map (function '-' -> '_' | c -> c) chars in
        Some (string_of_list chars)
    | None -> None
}
