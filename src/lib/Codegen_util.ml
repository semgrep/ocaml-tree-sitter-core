(*
   Various reusable utilities involved in code generation.
*)

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
