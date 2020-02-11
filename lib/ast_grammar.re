/* Essence of grammar.json content */

[@deriving show]
type ident = string;

[@deriving show { with_path : false} ]
type rule_body =
 /* composite (nodes) */
 | REPEAT(rule_body)
 | REPEAT1(rule_body)
 | CHOICE(list(rule_body))
 | SEQ(list(rule_body))
 | ALIAS(rule_body, ident) /* used in Java for AlIAS(identifier, type_identifier) */
 /* atomic (leaves) */
 | SYMBOL(ident)
 | STRING(string)
 | PATTERN(string)
 | TOKEN /* no need to look under that */
 | IMMEDIATE_TOKEN /* used in Ruby for keyword_parameter, IMMEDIATE_TOKEN(":") */
 | BLANK /* usually used in a CHOICE(...,BLANK) to encode optionality */
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