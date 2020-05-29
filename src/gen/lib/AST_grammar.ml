(*
   Type definition of a normalized tree-sitter grammar description.
*)

type ident = string

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

type token = {
  name: string;
    (* the node 'type' in tree-sitter's output.

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

       grammar.js:
         alias("*", "star")
       name: "star"

       grammar.js:
         alias("*", $.star)
       name: "star"

       grammar.js:
         alias($.times, $.star)
       name: "star"
    *)

  description: token_description;
    (* informational *)
}

type rule_body =
  (* atomic (leaves) *)
  | Symbol of ident
  | Token of token
  | Blank of ident option
     (* matches any sequence without consuming it.
        It comes with an optional name, which may help understand
        an AST. Such named zero-length sequences come from hidden tokens
        (whose name starts with an underscore). *)

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

  rules: rule list list;
    (* rules, grouped and sorted in dependency order. *)

  extras: string list;
    (* node names that don't belong to any rule and can occur anywhere,
       such as comments. *)
}

(* alias *)
type t = grammar

(* Rules whose name start with an underscore don't produce a node
   tree-sitter's output but instead insert the children inline.

   See https://tree-sitter.github.io/tree-sitter/creating-parsers#hiding-rules
*)
let is_inline rule_name =
  rule_name <> "" && rule_name.[0] = '_'

let is_leaf = function
  | Token _
  | Blank _ -> true
  | Symbol _
  | Repeat _
  | Repeat1 _
  | Choice _
  | Optional _
  | Seq _ -> false
