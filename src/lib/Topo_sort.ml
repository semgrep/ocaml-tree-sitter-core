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
  | Repeat x -> collect_names acc x
  | Choice l
  | Seq l -> List.fold_left (fun acc x -> collect_names acc x) acc l
  | Symbol name -> name :: acc
  | String _
  | Pattern _ -> acc

let extract_rule_deps (name, body) =
  let deps = collect_names [] body in
  (name, List.filter ((<>) name) deps)

let extract_deps rules =
  List.map extract_rule_deps rules

let index_names sorted_names =
  let tbl = Hashtbl.create 100 in
  List.iteri (fun i name -> Hashtbl.replace tbl name i) sorted_names;
  fun name -> Hashtbl.find_opt tbl name

let sort rules =
  let graph_data = extract_deps rules in
  match Tsort.sort graph_data with
  | Tsort.Sorted sorted_names ->
      let get_index = index_names sorted_names in
      let cmp (a, _) (b, _) = compare (get_index a) (get_index b) in
      let sorted_rules = List.sort cmp rules in
      Some sorted_rules
  | _ -> None
