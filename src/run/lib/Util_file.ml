(*
   Generic utilities not provided by OCaml.
*)

(* You should set this to true when you run code compiled by js_of_ocaml
 * so some functions can change their implementation and rely
 * less on non-portable API like Unix which does not work well under
 * node or in the browser.
*)
let jsoo = ref false

(*
   [copied from pfff/commons/Common.ml]

   This implementation works even with Linux files like /dev/fd/63
   created by bash's process substitution e.g.

     my-ocaml-program <(echo contents)

   See https://www.gnu.org/software/bash/manual/html_node/Process-Substitution.html

   In bash, '<(echo contents)' is replaced by something like
   '/dev/fd/63' which is a special file of apparent size 0 (as
   reported by `Unix.stat`) but contains data (here,
   "contents\n"). So we can't use 'Unix.stat' or 'in_channel_length'
   to obtain the length of the file contents. Instead, we read the file
   chunk by chunk until there's nothing left to read.

   Why such a function is not provided by the ocaml standard library is
   unclear.
*)

(* copied from `OSS/libs/commons/UFile.ml` *)
(* Temporary files created using Python's [tempfile.NamedTemporaryFiles] on
    Windows enables the [FILE_SHARE_DELETE] sharing mode. Files that have open
    handles with the [FILE_SHARE_DELETE] sharing mode can only be re-opened in
    that mode. To make sure we won't run into problems opening the file, we
    add the [O_SHARE_DELETE] flag when opening all files. *)
let win_safe_open_in_bin file : in_channel =
  Unix.openfile file [ O_CREAT; O_RDONLY; O_SHARE_DELETE ] 0o666
  |> Unix.in_channel_of_descr

let read_file path =
  if !jsoo then (let ic = open_in_bin path in
                 let s = really_input_string ic (in_channel_length ic) in
                 close_in ic;
                 s) else
    let buf_len = 4096 in
    let extbuf = Buffer.create 4096 in
    let buf = Bytes.create buf_len in
    let rec loop fd =
      match Unix.read fd buf 0 buf_len with
      | 0 -> Buffer.contents extbuf
      | num_bytes ->
          assert (num_bytes > 0);
          assert (num_bytes <= buf_len);
          Buffer.add_subbytes extbuf buf 0 num_bytes;
          loop fd
    in
    let fd = Unix.openfile path [Unix.O_RDONLY] 0 in
    Fun.protect
      ~finally:(fun () -> Unix.close fd)
      (fun () -> loop fd)
