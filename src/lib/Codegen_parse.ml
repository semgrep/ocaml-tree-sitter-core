(*
   Code generator for the AST.ml file.
*)

open! Printf
open! AST_grammar
open! Codegen_util
open Indent.Types

let format _grammar =
  [Line "\"TODO\""]

let generate grammar =
  let tree = format grammar in
  Indent.to_string tree
