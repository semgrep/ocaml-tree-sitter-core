(*
   Topological sorting of the type definitions.

   We use an off-the-shelf implementation that gives up if any cycle is found.
   Ideally, we should identify cycles and produce a topologically-sorted
   list of clusters. Atdgen does this internally but it's not done well
   and it could be worth revisiting.
*)

open AST_grammar

let rec collect_names acc x =
  match x with
  | Repeat x
  | Repeat1 x
  | Optional x -> collect_names acc x
  | Choice l
  | Seq l -> List.fold_left (fun acc x -> collect_names acc x) acc l
  | Symbol name -> name :: acc
  | String _
  | Pattern _
  | Blank -> acc

let extract_rule_deps (name, body) =
  let deps = collect_names [] body in
  (name, deps)

(* Generic function on top of Tsort.sort_strongly_connected_components *)
let tsort get_deps elts =
  let deps_data =
    List.map (fun elt ->
      let id, deps = get_deps elt in
      let self_dep = List.mem id deps in
      (id, deps, self_dep, elt)
    ) elts
  in
  let tbl = Hashtbl.create 100 in
  List.iter (fun ((id, _, _, _) as x) -> Hashtbl.replace tbl id x) deps_data;
  let tsort_input = List.map (fun (id, deps, _, _) -> (id, deps)) deps_data in
  let tsort_output = Tsort.sort_strongly_connected_components tsort_input in
  List.map (fun group ->
    List.map (fun id ->
      let _id, _deps, self_dep, elt =
        try Hashtbl.find tbl id
        with Not_found -> assert false
      in
      (self_dep, elt)
    ) group
  ) tsort_output

(*
   Sort a list of objects so as to minimize mutual dependencies in the
   generated code. Tsort works on elements IDs (rule names = strings).
   Here we take care of:
   - extracting the names of the dependencies of each rule
   - substituting the sorted names with the rules
*)
let sort rules =
  tsort extract_rule_deps rules
