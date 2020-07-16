(*
   Type definition of a normalized tree-sitter grammar description.
*)

type ident = string
[@@deriving show]

type token_description =
  | Constant of string
      (* A constant string defining a token.
         It is used as the name for the pattern if it's not the right-hand side
         of a named rule. *)

  | Pattern of string
      (* A regexp defining a set of valid tokens.
         It is used as the name for the pattern if it's not the right-hand side
         of a named rule.

        Sample pattern node in grammar.js:

          /[a-z]+/

        here:

          Pattern "[a-z]+"  (* shows up as "type":"[a-z]+" in tree-sitter
                               output. The actual token is extracted from
                               the source file using location fields. *)

        == Problem ==

        grammar.js:

          choice(/a+/, "a+")

        here:

          Choice [Pattern "a+", String "a+"]

        This presumably results in indistinguishable "type":"a+" fields in the
        tree-sitter output. This is a problem if they must be interpreted
        differently.
     *)

  | Token
      (* derived from a token() or token.immediate() construct.
         It may be derived from complex rules (omitted here) which result in
         a single token. *)

  | External
      (* a symbol declared in the 'externals' list and produced by an external
         C parser. *)
[@@deriving show]

type token = {
  name: string;
    (* the node 'type' in tree-sitter's output.
       It may not be an alphanumeric identifier.

       It is the enclosing rule name or alias, if there's one.
       Otherwise it's the 'value' field.

       The token(seq(...)) construct can result in a token without a name.
       We treat these as errors. See the '/tests/token' example.

       grammar.js:
         times: $ => "*"
       name: "times"

       grammar.js:
         repeat($.times)
       name of the repeated element: "times"

       grammar.js:
         repeat("*")
       name of the repeated element: "*"
    *)

  is_inlined: bool;
    (* always true for Constant tokens whose name is not an alphanumeric
       identifier. May be true or false for other kinds of tokens, depending
       on whether the type expression uses the 'Token.t' type directly
       (inlined) or the 'name' field (not inlined). *)

  description: token_description;
    (* informational *)
}
[@@deriving show]

type rule_body =
  (* atomic (leaves) *)
  | Symbol of ident
  | Token of token
  | Blank
     (* matches any sequence without consuming it. *)

  (* composite (nodes) *)
  | Repeat of rule_body (* zero or more *)
  | Repeat1 of rule_body (* one or more *)
  | Optional of rule_body (* zero or one *)
  | Choice of (ident * rule_body) list
     (* (name, type) where the name is the name of the ocaml constructor
        suitable for use a classic or polymorphic variant, e.g. "Exp_int". *)

  | Seq of rule_body list
[@@deriving show]

type rule = {
  name: ident;
  is_rec: bool;

  is_inlined: bool;
    (* An inlined rule is a type definition that was inlined everywhere
       it occurs in other type expressions.

       For example, consider the rule 'foo':
         type foo = [`Bar|`Baz]
         and type program = foo option

       Inlining 'foo' results in
         type program = [`Bar|`Baz] option
         type foo = [`Bar|`Baz]

       The rule 'foo' is now marked as inlined, and it can be ignored for
       some purposes.
*)

  body: rule_body;
}
[@@deriving show]

type grammar = {
  name: string;
  entrypoint: string;

  rules: rule list list;
    (* rules, grouped and sorted in dependency order. *)

  extras: string list;
    (* node names that don't belong to any rule and can occur anywhere,
       such as comments. *)
}
[@@deriving show]

(* alias *)
type t = grammar
[@@deriving show]

let is_leaf = function
  | Token _
  | Blank -> true
  | Symbol _
  | Repeat _
  | Repeat1 _
  | Choice _
  | Optional _
  | Seq _ -> false
