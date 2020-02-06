/* Normalized grammar.json, easier to work on */

type ident = string;

/* this is easier to translate into OCaml ADTs type definitions */

type atom = 
 | SYMBOL(ident)
 | TOKEN
 ;

type simple =
 | ATOM(atom)
 | SEQ(list(atom)) /* codegen: (A,B,C,...) */
;

type rule_body =
 | REPEAT(simple)       /* codegen: list(x) */
 | CHOICE(list(simple)) /* codegen: A(...) | B(...) */
 | OPTION(simple)       /* codegen: option(...) */
 | SIMPLE(simple)
;
type rule = (ident, rule_body);

type rules = list(rule);

type grammar = (ident /* entry point, first rule */, rules);

/* alias */
type t = grammar;
