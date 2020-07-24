(*
   Improve OCaml type definitions and boilerplate destined for human
   consumption:

   - Inline small definitions that are used only once.
   - Factor out and name large nodes that occur multiple times.
*)

let rearrange_rules grammar =
  grammar
  |> Factorize.factorize_rules
  |> Inline.inline_rules
