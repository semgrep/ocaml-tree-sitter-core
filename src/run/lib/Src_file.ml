(*
   Extract tokens from the input file using the locations in the tree-sitter
   output.

   TODO: check whether multibyte characters are supported. This will depend
   on whether the column file of the a location is expressed in bytes
   or in characters. Assuming the former for now.
*)

type info = {
  name: string;
  path: string option;
}

type t = {
  info: info;
  lines: string array;
}

let info x = x.info

let get_num_lines x = Array.length x.lines

let with_in_channel filename f =
  let ic = open_in filename in
  let finally () = close_in_noerr ic in
  try
    let res = f ic in
    finally ();
    res
  with e ->
    finally ();
    raise e

let read_lines filename =
  with_in_channel filename (fun ic ->
    let acc = ref [] in
    (try
       while true do
         acc := (input_line ic) :: !acc
       done;
       assert false
     with End_of_file ->
       ()
    );
    List.rev !acc
  )

let load_file src_file =
  {
    info = {
      name = src_file;
      path = Some src_file;
    };
    lines = Array.of_list (read_lines src_file);
  }

let load_string ?(src_name = "<source>") ?src_file src_contents =
  let info =
    match src_file with
    | None -> { name = src_name; path = None }
    | Some path -> { name = path; path = Some path }
  in
  let lines = String.split_on_char '\n' src_contents in
  {
    info;
    lines = Array.of_list lines;
  }

let safe_get_row x row =
  let lines = x.lines in
  if row >= 0 && row < Array.length lines then
    lines.(row)
  else
    ""

let safe_substring s start end_ =
  let start = max 0 start in
  let end_ = min (String.length s) end_ in
  let len = end_ - start in
  if len > 0 then
    String.sub s start len
  else
    ""

let safe_add_rest_of_line buf x row col =
  let line = safe_get_row x row in
  let s = safe_substring line col (String.length line) in
  Buffer.add_string buf s

let safe_add_whole_line buf x row =
  let line = safe_get_row x row in
  Buffer.add_string buf line

let safe_add_beginning_of_line buf x row end_col =
  let line = safe_get_row x row in
  let s = safe_substring line 0 end_col in
  Buffer.add_string buf s

(*
   (0, 0)...(0, 1) references a token of length 1 on the first line,
   first character.
*)
let get_region x start end_ =
  let open Loc in
  let first_row = start.row in
  let last_row = end_.row in
  if first_row = last_row then
    let line = safe_get_row x first_row in
    safe_substring line start.column end_.column
  else if first_row < last_row then
    let buf = Buffer.create 100 in
    safe_add_rest_of_line buf x first_row start.column;
    Buffer.add_string buf "\n";
    for row = first_row + 1 to last_row - 1 do
      safe_add_whole_line buf x row;
      Buffer.add_string buf "\n";
    done;
    safe_add_beginning_of_line buf x last_row end_.column;
    Buffer.contents buf
  else
    ""
