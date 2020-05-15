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
