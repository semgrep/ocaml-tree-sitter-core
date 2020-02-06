/*
 * The author disclaims copyright to this source code.  In place of
 * a legal notice, here is a blessing:
 *
 *    May you do good and not evil.
 *    May you find forgiveness for yourself and forgive others.
 *    May you share freely, never taking more than you give.
 */
open Common;

/*****************************************************************************/
/* Purpose */
/*****************************************************************************/
/* Generating OCaml code to read the Concrete Syntax Trees (CSTs) produced
 * by tree-sitter.
 */

/*****************************************************************************/
/* Flags */
/*****************************************************************************/

let verbose = ref(false);
let debug = ref(false);

let version = "0.1";

/* action mode */
let action = ref("");

/*****************************************************************************/
/* Helpers */
/*****************************************************************************/

/*****************************************************************************/
/* Main action */
/*****************************************************************************/
let main_action = _ => raise(Todo);

/*****************************************************************************/
/* The options */
/*****************************************************************************/

let all_actions = () => [] @ Test_tree_sitter.actions();

let options = () =>
  [
    ("-verbose", Arg.Unit(() => verbose := true), " "),
    (
      "-debug",
      Arg.Set(debug),
      " add debugging information in the output (e.g., tracing)",
    ),
  ]
  @ Common.options_of_actions(action, all_actions())
  @ Common2.cmdline_flags_devel()
  @ [
    (
      "-version",
      Arg.Unit(
        () => {
          pr2(spf("ocaml-tree-sitter version: %s", version));
          exit(0);
        },
      ),
      "  guess what",
    ),
  ];

/*****************************************************************************/
/* Main entry point */
/*****************************************************************************/

let main = () => {
  let usage_msg =
    spf("Usage: %s [options]  \nOptions:", Filename.basename(Sys.argv[0]));

  /* does side effect on many global flags */
  let args = Common.parse_options(options(), usage_msg, Sys.argv);

  /* must be done after Arg.parse, because Common.profile is set by it */
  Common.profile_code("Main total", () =>
    switch (args) {
    /* --------------------------------------------------------- */
    /* actions, useful to debug subpart */
    /* --------------------------------------------------------- */
    | xs when List.mem(action^, Common.action_list(all_actions())) =>
      Common.do_action(action^, xs, all_actions())

    | _ when !Common.null_string(action^) =>
      failwith("unrecognized action or wrong params: " ++ action^)

    /* --------------------------------------------------------- */
    /* main entry */
    /* --------------------------------------------------------- */
    | [x, ...xs] => main_action([x, ...xs])

    /* --------------------------------------------------------- */
    /* empty entry */
    /* --------------------------------------------------------- */
    | [] => Common.usage(usage_msg, options())
    }
  );
};

/*****************************************************************************/
let _ = Common.main_boilerplate(() => main());
