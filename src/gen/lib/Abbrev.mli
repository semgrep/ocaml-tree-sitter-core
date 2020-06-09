(*
   Abbreviations for common words, to be used in generated names.
   These are meant to be better than truncating a word at an arbitrary
   offset.
*)

(* Abbreviate the ascii words found in the input string, using known
   abbreviations such as 'exp' for 'expression' when possible,
   otherwise truncating words to 'trunc_len'.

   All-caps words are not abbreviated.
*)
val words : ?trunc_len:int -> string -> string
