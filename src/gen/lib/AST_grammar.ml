(*
   Type definition of a normalized tree-sitter grammar description.
*)

type ident = string

type rule_body =
  (* atomic (leaves) *)
  | Symbol of ident
  | String of string
  | Pattern of string
  | Blank

  (* composite (nodes) *)
  | Repeat of rule_body
  | Repeat1 of rule_body
  | Choice of rule_body list
  | Optional of rule_body
  | Seq of rule_body list

type rule = {
  name: ident;
  is_rec: bool;
  body: rule_body;
}

type grammar = {
  name: string;
  entrypoint: string;

  (* rules, grouped and sorted in dependency order. *)
  rules: rule list list;
}

(* alias *)
type t = grammar
