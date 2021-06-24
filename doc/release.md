Releasing generated code for semgrep
==

The process for updating a grammar and releasing the generated code in
described in details [in this document](updating-a-grammar.md).

Until we have an automatic process for this and for security reasons,
please ask someone at r2c to release the code for the language.

Contact channels:
* your ocaml-tree-sitter pull request
* the [r2c Slack channel #dev-discussions](https://r2c.slack.com/archives/dev-discussions/)

Step 1: Check the sources
--

Check that the external source code looks clean, including any
dependency used at build time or run time. Source code for a
tree-sitter-* grammar is:
* `grammar.js` and its dependencies. `grammar.js` should just define a
  grammar object. It should not write to the filesystem.
* `src/scanner.c` or `src/scanner.cc` if such file exists, and any
  dependency they may have. There should be no dependency other
  the standard C or C++ libraries and tree-sitter libraries.

Step 2: Generate and push to GitHub
--

For a language `foolang`, the commands are:

```
make && make install
cd lang
./test-lang foolang
./release foolang
```

This will push to the git repository for `semgrep-foolang`, which will
then be used in semgrep as a git submodule.
