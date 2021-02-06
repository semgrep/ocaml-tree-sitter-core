*Heads up: simplifications to this setup are in progress. Friday 2021-02-05*

How to upgrade the grammar for a language
==

Let's call our language "X".

Here's the chain of relevant git repositories, in dependency order:

* tree-sitter-X e.g.,
  [tree-sitter-ruby](https://github.com/tree-sitter/tree-sitter-ruby):
  the original tree-sitter grammar for the language.
  Git submodule of semgrep-grammars.
* [semgrep-grammars](https://github.com/returntocorp/semgrep-grammars):
  the collection of tree-sitter grammars supported by semgrep,
  with semgrep-specific extensions such as dots (`...`) and
  metavariables (`$FOO`). Uses tree-sitter-X as a git submodule. Is a
  submodule of ocaml-tree-sitter.
* [ocaml-tree-sitter](https://github.com/returntocorp/ocaml-tree-sitter):
  generates OCaml parsing code from tree-sitter grammars provided by
  semgrep-grammars and publishes that code into
  ocaml-tree-sitter-lang. Uses semgrep-grammars as a submodule. Writes
  to ocaml-tree-sitter-lang.
* [ocaml-tree-sitter-lang](https://github.com/returntocorp/ocaml-tree-sitter-lang):
  provides generated OCaml/C parsers as a dune project. Is a submodule
  of semgrep.
* [semgrep](https://github.com/returntocorp/semgrep): uses the parsers
  provided by ocaml-tree-sitter-lang, which produce a CST. The
  program's CST or pattern's CST is further transformed into an AST
  suitable for pattern matching.

We're going to work mostly with semgrep-grammars and with
ocaml-tree-sitter. The above should be clear in your mind before
proceeding further.

Before upgrading
--

Make sure the `grammar.js` file or equivalent source files
defining the grammar are included in the `fyi.list` file in
`ocaml-tree-sitter/lang/X`.

Why: It is important for tracking and _understanding_ the changes made at the
source.

How: See [How to add support for a new language](adding-a-language.md).

Upgrade the submodule in semgrep-grammars
--

Say you want to upgrade (or downgrade) tree-sitter-X from some old
commit to commit `602f12b`. This uses the git submodule way, without
anything weird. Go to a copy of the `semgrep-grammars` repo and change
the commit of the `tree-sitter-X` submodule to `602f12b`. The commands
might be something like this:

```
git clone https://github.com/returntocorp/semgrep-grammars
cd semgrep-grammars
  git submodule update --init --recursive --depth 1
  cd src/tree-sitter-X
    git fetch origin
    git checkout 602f12b
    cd ..
  git status
  git commit -a
  git push origin master
```

Upgrade the submodule in ocaml-tree-sitter
--

Since semgrep-grammars itself is a submodule of ocaml-tree-sitter and
we just pushed a commit to it, we need to update it as well. Again,
this is ordinary use of a submodule. Commands would look like this:

```
git clone https://github.com/returntocorp/ocaml-tree-sitter
cd ocaml-tree-sitter
git checkout -b upgrade-X
git submodule update --init --recursive --depth 1
cd lang
  cd semgrep-grammars
    git pull origin master
```

Testing
--

First, build and install ocaml-tree-sitter normally, based on the
instructions found in the [main README](../README.md) or in the
[Dockerfile](../Dockerfile).

```
./configure
make setup
make
make install
```

Then, build support for the languages in `lang/`. The following
commands will build and test all languages at once:

```
cd lang
  make
  make test
```

If this works, we're all set and we can consider publishing the code
to ocaml-tree-sitter-lang.

Publishing
--

From the `lang` folder of ocaml-tree-sitter, we'll perform the
release. This step redoes some of the work that was done earlier and
checks that everything is clean before committing and pushing the
changes to ocaml-tree-sitter-lang.

```
cd lang
  make dry      # a dry-run release
  ...           # inspect things
  make release  # commit and push ocaml-tree-sitter-lang
```

If something goes wrong for a particular language, it is faster to
call the `release` script directly, only for the specific language X:

```
cd lang
  ./release --dry-run X
```

Using the parsers
--

From the semgrep repository, point to the latest ocaml-tree-sitter-lang
and see what changes. If the source `grammar.js` was included, `git
diff` should help figure out the changes since the last version.

Conclusion
--

The main difficulty is to understand how the different git projects
interact and to not make mistakes when dealing with git submodules,
which takes a bit of practice.

See also
--

[How to add support for a new language](adding-a-language.md)
