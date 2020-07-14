(*
   Change the name of identifiers that would make unsuitable Reason
   identifiers.
*)

open Printf

let ocaml_keywords = [
  "and";
  "as";
  "assert";
  "asr";
  "begin";
  "class";
  "constraint";
  "do";
  "done";
  "downto";
  "else";
  "end";
  "exception";
  "external";
  "false";
  "for";
  "fun";
  "function";
  "functor";
  "if";
  "in";
  "include";
  "inherit";
  "initializer";
  "";
  "land";
  "lazy";
  "let";
  "lor";
  "lsl";
  "lsr";
  "lxor";
  "match";
  "method";
  "mod";
  "module";
  "mutable";
  "new";
  "nonrec";
  "object";
  "of";
  "open";
  "or";
  "private";
  "rec";
  "sig";
  "struct";
  "then";
  "to";
  "true";
  "try";
  "type";
  "val";
  "virtual";
  "when";
  "while";
  "with";
]

let ocaml_builtin_types = [
  "unit";
  "bool";
  "int";
  "float";
  "string";
  "bytes";
  "list";
  "array";
  "option";
]

let ocaml_reserved = ocaml_keywords @ ocaml_builtin_types

(*
   Map from input identifier to output identifier and vice-versa.
   This map is initialized with the reserved keywords of the output language,
   and then filled with identifiers as they are encountered in the program.
*)
type t = {
  forward: (string, string) Hashtbl.t;
  backward: (string, string) Hashtbl.t;
}

type translation_status =
  | Available
  | Valid
  | Invalid

(* Check that src could map to dst and vice-versa. *)
let check x src dst =
  match Hashtbl.find_opt x.forward src, Hashtbl.find_opt x.backward dst with
  | None, None -> Available
  | Some dst', Some src' when src' = src && dst' = dst -> Valid
  | _ -> Invalid

let force_add x a b =
  Hashtbl.replace x.forward a b;
  Hashtbl.replace x.backward b a

let create ~reserved =
  let x = {
    forward = Hashtbl.create 100;
    backward = Hashtbl.create 100;
  } in
  List.iter (fun src ->
    let dst = src ^ "_" in
    match check x src dst with
    | Available -> force_add x src dst
    | Valid -> ()
    | Invalid -> invalid_arg (sprintf "Protect_ident.create: %s" src)
  ) reserved;
  x

(* Try these suffixes first before falling back to random numbers. *)
let good_suffixes = [
  "";
  "_";
  "2"; "3"; "4"; "5";
]

let find_available x src preferred_dst =
  let rec try_suffix suffixes =
    let candidate_suffix, suffixes =
      match suffixes with
      | [] -> (Random.bits () |> string_of_int), []
      | x :: xs -> x, xs
    in
    let dst = preferred_dst ^ candidate_suffix in
    match check x src dst with
    | Available ->
        force_add x src dst;
        dst
    | Valid ->
        dst
    | Invalid ->
        try_suffix suffixes
  in
  try_suffix good_suffixes

(*
   Forward translation of an identifier. For example, "object" returns
   "object_". "object_" might then return something like "object__".
*)
let translate x src =
  match Hashtbl.find_opt x.forward src with
  | Some dst -> dst
  | None -> find_available x src src

let reserve x ~src ~preferred_dst =
  find_available x src preferred_dst
