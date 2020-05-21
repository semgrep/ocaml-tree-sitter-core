(* Extract ALIAS nodes and assign them globally-unique names.

   What are aliases in a tree-sitter grammar?

   The official documentation says:

     Aliases : alias(rule, name) - This function causes the given rule
     to appear with an alternative name in the syntax tree. If name is a
     symbol, as in alias($.foo, $.bar), then the aliased rule will
     appear as a named node called bar. And if name is a string literal,
     as in alias($.foo, 'bar'), then the aliased rule will appear as an
     anonymous node, as if the rule had been written as the simple
     string.

   So, the same construct is used to implement two very different features
   from our perspective: named aliases and anonymous aliases.

   Contents:

   1. Named aliases (what this module helps dealing with)
   2. Anonymous aliases
   3. Our implementation

   1. Named aliases
   ================

   Example:

     module.exports = grammar({
       name: "name_alias",
       rules: {
         program: $ => optional(
           alias($.numbers, $.items)
         ),
         numbers: $ => repeat1($.number),
         number: $ => /[0-9]+/
       }
     });

  One way to write it without the alias feature would be:

  Tree-sitter's output for the file containing '1 2 3':

    {
      "type": "program",
      "startPosition": { "row": 0, "column": 0 },
      "endPosition": { "row": 1, "column": 0 },
      "children": [
        {
          "type": "items",
          "startPosition": { "row": 0, "column": 0 },
          "endPosition": { "row": 0, "column": 5 },
          "children": [
            {
              "type": "number",
              "startPosition": { "row": 0, "column": 0 },
              "endPosition": { "row": 0, "column": 1 },
              "children": []
            },
            {
              "type": "number",
              "startPosition": { "row": 0, "column": 2 },
              "endPosition": { "row": 0, "column": 3 },
              "children": []
            },
            {
              "type": "number",
              "startPosition": { "row": 0, "column": 4 },
              "endPosition": { "row": 0, "column": 5 },
              "children": []
            }
          ]
        }
      ]
    }

  The OCaml representation for this is essentially: Some ["1"; "2"; "3"].

  Note that the node containing the repeat1 elements is labeled "items"
  rather than "numbers". This is what named aliases do.

  In terms of OCaml types, it's the same as a type alias:

    type items = numbers

  For interpreting the json output from tree-sitter, we must expect
  to find a '"type": "items"' instead of '"type": "numbers"'. Parsing the
  children of an "items" or "numbers" node is the same, however.

  The authors of grammars could totally do without named aliases.
  The example grammar would become:

       module.exports = grammar({
       name: "name_alias",
       rules: {
         program: $ => optional(
           $.items
         ),
         items: $ => $.numbers,
         numbers: $ => repeat1($.number),
         number: $ => /[0-9]+/
       }
     });

  Unfortunately for us, aliases are local, they don't have to be globally
  unique like rule names. The following is legal:

    module.exports = grammar({
      name: "alias_scope",
      rules: {
        program: $ => seq(
          alias($.number, $.elt),  // elt
          alias($.pair, $.elt)     // elt, again
        ),
        pair: $ => seq($.number, $.number),
        number: $ => /[0-9]+/
      }
    });

  'elt' is a local type name, used twice to refer to different types.
  The OCaml types would be:

    type number = string
    type pair = number * number
    type elt = number
    type elt_ = pair

  In order to generate this code, we have to find all aliases and create
  uniquely-named type definitions and parsing functions.


  2. Anonymous aliases
  ====================

  From our perspective, these are totally different from named aliases.
  The intent of an anonymous alias is to present the result of matching a rule
  as a single token.
  As a reader of tree-sitter's output, we're happy to take a token,
  and we can ignore the underlying parsing rules. Note that the json
  output of tree-sitter (see example below) contains children nodes
  corresponding to the matched children. We ignore those and return the
  whole subtree as one token.

  Example:

    module.exports = grammar({
      name: "string_alias",
      rules: {
        program: $ => optional(
          alias(repeat1($.number), '*')  // '*' could be any string instead.
        ),
        number: $ => /[0-9]+/
      }
    });

  From the input file containing "1 2 3", the result of parsing should
  be successful and return the three numbers as a single string.
  The OCaml result would be 'Some "1 2 3"', rather than 'Some ["1"; "2"; "3"]'
  without the alias.

  Commented json output from tree-sitter:

    {
      "type": "program",
      "startPosition": { "row": 0, "column": 0 },
      "endPosition": { "row": 1, "column": 0 },
      "children": [
        {
          "type": "*",  // used to determine if we matched the right thing
          "startPosition": { "row": 0, "column": 0 },  // used to extract token
          "endPosition": { "row": 0, "column": 5 },    // from source file

          // children are ignored
          "children": [
            {
              "type": "number",
              "startPosition": { "row": 0, "column": 0 },
              "endPosition": { "row": 0, "column": 1 },
              "children": []
            },
            {
              "type": "number",
              "startPosition": { "row": 0, "column": 2 },
              "endPosition": { "row": 0, "column": 3 },
              "children": []
            },
            {
              "type": "number",
              "startPosition": { "row": 0, "column": 4 },
              "endPosition": { "row": 0, "column": 5 },
              "children": []
            }
          ]
        }
      ]
    }

  3. Our implementation
  =====================

  We treat anonymous aliases are simply treated as STRING constructs,
  ignoring the rules that would be necessary to parse the source file.
  Tree-sitter deals with this for us.

  Named aliases however a really just type aliases, with the catch that
  the name specified in the tree-sitter grammar is local. As we saw
  earlier, 'elt' was used to refer to two different types. To deal with
  this, we give them separate OCaml type names such as 'elt', 'elt_',
  'elt2', etc. Our 'Fresh' module takes care of generating such unique names
  that remain close to the original.

  An alternative implementation would be to strip the original grammar from
  all named aliases. This would probably make the resulting AST less obvious
  to interpret, so we keep aliases. Additionally, this stripping would
  require a preprocessing step on 'grammar.json' so that the tree-sitter
  parser doesn't expose renamed nodes.
*)

(*
   This returns pairs of the form (rule_name, aliases).
   Each alias.id can be used as a new rule name without conflicts.
*)
val extract_named_aliases :
  (string * Tree_sitter_t.rule_body) list ->
  (string * AST_grammar.alias list) list
