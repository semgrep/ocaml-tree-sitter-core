How to upgrade the grammar for a language
==

Let's call our language "X".

Here are the main components:

* the OCaml code generator
  [ocaml-tree-sitter](https://github.com/returntocorp/ocaml-tree-sitter):
  generates OCaml parsing code from tree-sitter grammars extended
  with `...` and such. Publishes code into the git repos of the
  form `semgrep-X`.
* the original tree-sitter grammar `tree-sitter-X` e.g.,
  [tree-sitter-ruby](https://github.com/tree-sitter/tree-sitter-ruby):
  the original tree-sitter grammar for the language.
  This is the git submodule `lang/semgrep-grammars/src/tree-sitter-X`
  in ocaml-tree-sitter. It is installed at the project's root
  in `node_modules` by invoking `npm install`.
* syntax extensions to support semgrep patterns, such as ellipses
  (`...`) and metavariables (`$FOO`).
  This is `lang/semgrep-grammars/src/semgrep-X`. It can be tested from
  that folder with `make && make test`.
* an automatically-modified grammar for language X in `lang/X`.
  It is modified so as to accommodate various requirements of the
  ocaml-tree-sitter code generator. `lang/X/src` and
  `lang/X/ocaml-src` contain the C/C++/OCaml code that will published
  into semgrep-X e.g.
  [semgrep-ruby](https://github.com/returntocorp/semgrep-ruby)
  and used by semgrep.
* [semgrep-X](https://github.com/returntocorp/semgrep-ruby):
  provides generated OCaml/C parsers as a dune project. Is a submodule
  of semgrep.
* [semgrep](https://github.com/returntocorp/semgrep): uses the parsers
  provided by semgrep-X, which produce a CST. The
  program's CST or pattern's CST is further transformed into an AST
  suitable for pattern matching.

Make sure the above is clear in your mind before proceeding further.
If you have questions, the best way is reach out on our
[community Slack channel](https://r2c.dev/slack).

Before upgrading
--

Make sure the `grammar.js` file or equivalent source files
defining the grammar are included in the `fyi.list` file in
`ocaml-tree-sitter/lang/X`.

Why: It is important for tracking and _understanding_ the changes made at the
source.

How: See [How to add support for a new language](adding-a-language.md).

Upgrade the tree-sitter-X submodule
--

Say you want to upgrade (or downgrade) tree-sitter-X from some old
commit to commit `602f12b`. This uses the git submodule way, without
anything weird. The commands might be something like this:

```
git submodule update --init --recursive --depth 1
git checkout -b upgrade-X
cd lang/semgrep-grammars/src/tree-sitter-X
  git fetch origin --unshallow
  git checkout 602f12b
  cd ..
```

Testing
--

First, build and install ocaml-tree-sitter normally, based on the
instructions found in the [main README](../README.md).

```
./configure
make setup
make
make install
```

Then, build support for your language in `lang/`. The following
commands will build and test the language:

```
cd lang
  ./test-lang X
```

If this works, we're all set. Commit the new commit for the
tree-sitter-X submodule:
```
git status
git commit semgrep-languages/semgrep-X
git push origin upgrade-X
```

Then make a pull request to merge this into ocaml-tree-sitter's
main branch. It's ok to merge at this point, even if the generated code
hasn't been exported (**Publishing** section below) or if you haven't
done the necessary changes in semgrep (**Semgrep integration** below).

We can now consider publishing the code to semgrep-X.

Publishing
--

From the `lang` folder of ocaml-tree-sitter, we'll perform the
release. This step redoes some of the work that was done earlier and
checks that everything is clean before committing and pushing the
changes to semgrep-X.

```
cd lang
  ./release --dry-run X  # dry-run release
  ...                    # inspect things
  ./release X  # commits and pushes to semgrep-X
```

This step is safe. Semgrep at this point is unaffected by those changes.

Semgrep integration
--

From the semgrep repository, point the submodule for semgrep-X to the
latest commit from the "Publishing" step. Then rebuild semgrep-core,
which will normally fail if the grammar changed. If the source
`grammar.js` was included in the `fyi` folder for `semgrep-X` (as it
should), `git diff HEAD^` should help figure out the changes since the
last version.

Conclusion
--

The main difficulty is to understand how the different git projects
interact and to not make mistakes when dealing with git submodules,
which takes a bit of practice.

See also
--

[How to add support for a new language](adding-a-language.md)
