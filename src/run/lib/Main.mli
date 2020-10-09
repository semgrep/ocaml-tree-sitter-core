(*
   Entrypoint for a standalone parser-dumper, to be called by generated
   parsers.
*)
val run :
  lang:string ->
  parse_source_file:(string -> Tree_sitter_parsing.t) ->
  parse_input_tree:(Tree_sitter_parsing.t ->
                    'a option * Tree_sitter_error.t list) ->
  dump_tree:('a -> unit) -> unit
