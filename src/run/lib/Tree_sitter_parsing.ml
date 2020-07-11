(*
   Parse a source file or load its json representation.
*)

open Tree_sitter_bindings

type t = {
  src: Src_file.t;
  root: Tree_sitter_output_t.node
}

let src x = x.src
let root x = x.root

let assign_unique_ids root_node =
  let open Tree_sitter_output_t in
  let counter = ref (-1) in
  let create_id () = incr counter; !counter in
  let rec map node =
    let id = create_id () in
    assert (id >= 0);
    let children = List.map map node.children in
    { node with id; children }
  in
  map root_node

let parse_json_file json_file =
  Atdgen_runtime.Util.Json.from_file
    Tree_sitter_output_j.read_node
    json_file
  |> assign_unique_ids

let load_json_file ~src_file ~json_file =
  let root = parse_json_file json_file in
  let src = Src_file.load_file src_file in
  { src; root }

let string_of_file file =
  let len = (Unix.stat file).Unix.st_size in
  let ic = open_in_bin file in
  Fun.protect
    ~finally:(fun () -> close_in ic)
    (fun () ->
       really_input_string ic len
    )

let parse_source_string ?src_file ts_parser src_data =
  let src = Src_file.load_string ?src_file src_data in
  let root =
    Tree_sitter_API.Parser.parse_string ts_parser src_data
    |> Tree_sitter_output.of_ts_tree
  in
  { src; root }

let parse_source_file ts_parser src_file =
  let src_data = string_of_file src_file in
  parse_source_string ~src_file ts_parser src_data

let print_json src =
  Atdgen_runtime.Util.Json.to_string
    Tree_sitter_output_j.write_node
    src.root
  |> Yojson.Safe.prettify
  |> print_endline
