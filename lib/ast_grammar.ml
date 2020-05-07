(* Essence of grammar.json content *)

type ident = string [@@deriving show]

type rule_body =
  (* composite (nodes) *)
  | REPEAT of rule_body
  | CHOICE of rule_body list
  | SEQ of rule_body list

  (* atomic (leaves) *)
  | SYMBOL of ident
  | STRING of string
  | PATTERN of string [@@deriving show { with_path = false }]

type rule = (ident * rule_body) [@@deriving show]
type rules = rule list [@@deriving show]
type grammar = (ident * rules) [@@deriving show]

(* alias *)
type t = grammar [@@deriving show]
