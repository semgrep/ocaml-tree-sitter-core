/* Essence of grammar.json content */

[@deriving show]
type ident = string;

[@deriving show { with_path : false} ]
type rule_body =
 /* composite (nodes) */
 | REPEAT(rule_body)
 | CHOICE(list(rule_body))
 | SEQ(list(rule_body))
 /* atomic (leaves) */
 | SYMBOL(ident)
 | STRING(string)
 | PATTERN(string)
;

[@deriving show]
type rule = (ident, rule_body);

[@deriving show]
type rules = list(rule);

[@deriving show]
type grammar = (ident /* entry point, first rule */, rules);

/* alias */
[@deriving show]
type t = grammar;