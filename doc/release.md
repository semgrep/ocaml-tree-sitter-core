Releasing generated code for semgrep
==

The process for updating a grammar and releasing the generated code in
described in details [in this document](updating-a-grammar.md).

Until we have an automatic process for this and for security reasons,
please ask someone at r2c to release the code for the language. For a
language `foolang`, the commands are:

```
make && make install
cd lang
./test-lang foolang
./release foolang
```

This will push to the git repository for `semgrep-foolang`, which will
then be used in semgrep as git submodule.

Contact channels:
* your ocaml-tree-sitter pull request
* the [r2c Slack channel #dev-discussions](https://r2c.slack.com/archives/dev-discussions/)
