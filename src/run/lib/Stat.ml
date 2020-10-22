(*
   Export some parsing stats to a file.

   Format:

     123 5 2
     ^^^ ^ ^
     |   | +- number of errors
     |   +--- number of lines affected by an error
     +------- total number of lines in the file

   These numbers are on a single line, separated by a single space character.
*)

open Printf

type t = {
  total_line_count: int;
  error_line_count: int;
  error_count: int;
}

let count_lines file =
  (* horrible but simple, kinda *)
  let ic = open_in file in
  Fun.protect
    ~finally:(fun () -> close_in_noerr ic)
    (fun () ->
       let n = ref 0 in
       try
         while true do
           ignore (input_line ic);
           incr n
         done;
         assert false
       with End_of_file -> !n
    )

let count_error_lines errors =
  (* Make sure to count a line just once if it contains more
     than one error. *)
  let tbl = Hashtbl.create 1000 in
  List.iter (fun (err : Tree_sitter_error.t) ->
    for row = err.start_pos.row to err.end_pos.row do
      Hashtbl.replace tbl row ()
    done
  ) errors;
  Hashtbl.length tbl

let extract src_file success errors =
  let total_line_count = count_lines src_file in
  let error_line_count =
    if success then
      count_error_lines errors
    else
      total_line_count
  in
  let error_count = List.length errors in
  {
    total_line_count;
    error_line_count;
    error_count;
  }

let export ~out_file x =
  let contents =
    sprintf "%i %i %i\n"
      x.total_line_count x.error_line_count x.error_count
  in
  let oc = open_out out_file in
  Fun.protect
    ~finally:(fun () -> close_out_noerr oc)
    (fun () -> output_string oc contents)
