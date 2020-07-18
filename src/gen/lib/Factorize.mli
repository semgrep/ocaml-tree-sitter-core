(*
   As part of the simplify-grammar program, identify duplicated anonymous
   rules and give them a name.
*)
val factorize_rules : ?min_size:int -> CST_grammar.t -> CST_grammar.t
