/* Normalized grammar.json, easier to work on */

[@deriving show]
type ident = string;

/* this is easier to translate into OCaml ADTs type definitions */

[@deriving show]
type atom =
 | SYMBOL(ident)
 | TOKEN
 ;

[@deriving show]
type simple =
 | ATOM(atom)
 | SEQ(list(atom)) /* codegen: (A,B,C,...) */
;

[@deriving show]
type rule_body =
 | REPEAT(simple)       /* codegen: list(x) */
 | CHOICE(list(simple)) /* codegen: A(...) | B(...) */
 | OPTION(simple)       /* codegen: option(...) */
 | SIMPLE(simple)
;
[@deriving show]
type rule = (ident, rule_body);

[@deriving show]
type rules = list(rule);

[@deriving show]
type grammar = (ident /* entry point, first rule */, rules);

[@deriving show]
/* alias */
type t = grammar;
