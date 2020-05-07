type ident = string[@@deriving show]
type rule_body =
  | REPEAT of rule_body 
  | CHOICE of rule_body list 
  | SEQ of rule_body list 
  | SYMBOL of ident 
  | STRING of string 
  | PATTERN of string [@@deriving show { with_path = false }]
type rule = (ident * rule_body)[@@deriving show]
type rules = rule list[@@deriving show]
type grammar = (ident * rules)[@@deriving show]
type t = grammar[@@deriving show]