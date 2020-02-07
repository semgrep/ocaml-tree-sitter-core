/* Essence of grammar.json content */

type ident = string;

type rule_body =
 /* composite (nodes) */
 | REPEAT(rule_body)
 | CHOICE(list(rule_body))
 | SEQ(list(rule_body))
 /* atomic (leaves) */
 | SYMBOL(ident)
 | STRING(string)
 | PATTERN(string)
 | TOKEN /* no need to look under that */
 | BLANK /* usually used in a CHOICE(...,BLANK) to encode optionality */
;


type rule = (ident, rule_body);

type rules = list(rule);

type grammar = (ident /* entry point, first rule */, rules);

/* alias */
type t = grammar;