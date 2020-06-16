(*
   This was taken from the dune manual at
   https://dune.readthedocs.io/en/stable/quick-start.html
*)
module C = Configurator.V1

let () =
  C.main ~name:"foo" (fun c ->
    let default : C.Pkg_config.package_conf = {
      libs = ["-ltree-sitter"];
      cflags = []
    }
    in
    let conf =
      match C.Pkg_config.get c with
      | None -> default
      | Some pc ->
          match C.Pkg_config.query pc ~package:"tree-sitter" with
          | None -> default
          | Some deps -> deps
    in
    C.Flags.write_sexp "c_flags.sexp" conf.cflags;
    C.Flags.write_sexp "c_library_flags.sexp" conf.libs)
