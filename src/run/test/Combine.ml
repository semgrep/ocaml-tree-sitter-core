(*
   Unit tests for the Combine module.
*)

open Tree_sitter_run
open Tree_sitter_bindings.Tree_sitter_output_t

let dummy_pos = { row = 0; column = 0 }

let new_id =
  let counter = ref 0 in
  fun () -> incr counter; !counter

let create_node type_ children = {
  type_;
  children;
  start_pos = dummy_pos;
  end_pos = dummy_pos;
  id = new_id ();
}

let a = create_node "a" []
let b = create_node "b" []
let c = create_node "c" []
let node_parent_a = create_node "(a)" [a]
let node_parent_ab = create_node "(ab)" [a; b]
let node_parent_abc = create_node "(abc)" [a; b; c]
let node_parent_aa = create_node "(aa)" [a; a]
let node_parent_aaa = create_node "(aaa)" [a; a; a]

(* Consume one node of the specified type. *)
let parse_node type_ nodes =
  Combine.parse_node (fun node ->
    if node.type_ = type_ then
      Some type_
    else
      None
  ) nodes

let test_seq () =
  assert (
    Combine.parse_seq
      (parse_node "a")
      Combine.parse_success
      []
    = None
  );
  assert (
    Combine.parse_seq
      (parse_node "a")
      Combine.parse_success
      [a; b]
    = Some (("a", ()), [b])
  );
  assert (
    Combine.parse_seq
      (parse_node "a")
      Combine.parse_end
      [a; b]
    = None
  )

let test_optional () =
  assert (
    Combine.parse_optional
      (parse_node "a")
      Combine.parse_success
      [b]
    = Some ((None, ()), [b])
  );
  assert (
    Combine.parse_optional
      (parse_node "a")
      Combine.parse_success
      [a; b]
    = Some ((Some "a", ()), [b])
  );
  assert (
    Combine.parse_optional
      (parse_node "a")
      Combine.parse_end
      [a; b]
    = None
  );
  assert (
    Combine.parse_optional
      (parse_node "a")
      Combine.parse_end
      [a]
    = Some ((Some "a", ()), [])
  )

let test_repeat () =
  assert (
    Combine.parse_repeat
      (parse_node "a")
      Combine.parse_success
      []
    = Some (([], ()), [])
  );
  assert (
    Combine.parse_repeat
      (parse_node "a")
      Combine.parse_success
      [a; b]
    = Some ((["a"], ()), [b])
  );
  assert (
    Combine.parse_repeat
      (parse_node "a")
      Combine.parse_end
      [a; b]
    = None
  );
  assert (
    Combine.parse_repeat
      (parse_node "a")
      Combine.parse_end
      [a; a]
    = Some ((["a"; "a"], ()), [])
  )

let test_repeat1 () =
  assert (
    Combine.parse_repeat1
      (parse_node "a")
      Combine.parse_success
      []
    = None
  );
  assert (
    Combine.parse_repeat1
      (parse_node "a")
      Combine.parse_success
      [a; b]
    = Some ((["a"], ()), [b])
  );
  assert (
    Combine.parse_repeat1
      (parse_node "a")
      Combine.parse_end
      [a; b]
    = None
  );
  assert (
    Combine.parse_repeat1
      (parse_node "a")
      Combine.parse_end
      [a; a]
    = Some ((["a"; "a"], ()), [])
  )

let test_opt_repeat1 () =
  assert (
    Combine.parse_optional
      (Combine.parse_repeat1
         (parse_node "a")
         Combine.parse_end
      )
      Combine.parse_success
      [a]
    = Some ((Some (["a"], ()), ()), [])
  )

let test = "Combine", [
  "seq", `Quick, test_seq;
  "optional", `Quick, test_optional;
  "repeat", `Quick, test_repeat;
  "repeat1", `Quick, test_repeat1;
  "opt repeat1", `Quick, test_opt_repeat1;
]
