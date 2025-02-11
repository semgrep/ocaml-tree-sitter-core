(*
   This was taken from the dune manual at
   https://dune.readthedocs.io/en/stable/quick-start.html
*)
module C = Configurator.V1

let () =
  C.main ~name:"foo" (fun c ->
    let libs =
      (* The -rpath option tells the linker to hardcode this search location in
         the binary.
         This works as long as libtree-sitter stays where it is, which is fine
         for test executables. Production executables should instead link
         statically against libtree-sitter to avoid problems in locating the
         library at runtime. *)
      match C.ocaml_config_var c "os_type" with
      | Some "Win32" -> [] (* Compilation on Windows does not support rpath *)
      | _ -> ["-Wl,-rpath,%{env:TREESITTER_LIBDIR=/usr/local/lib}"]
    in
    let default : C.Pkg_config.package_conf = {
      libs;
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
    let cflags =
      match C.ocaml_config_var c "ccomp_type" with
      | Some "cc" -> ["-Wall"]
      | _ -> failwith "msvc compilation isn't supported"
    in
    let conf = { conf with cflags = conf.cflags @ cflags } in
    C.Flags.write_sexp "c_flags.sexp" conf.cflags;
    C.Flags.write_sexp "c_library_flags.sexp" conf.libs)
