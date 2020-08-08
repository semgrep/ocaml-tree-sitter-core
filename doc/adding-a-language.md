How to add support for a new language
==

As a model, you can use the existing setup for `ruby` or `javascript`. Our
most complicated setup is for `typescript` and `tsx`.

First, extend the language with semgrep pattern syntax in the
[semgrep-grammars](https://github.com/returntocorp/semgrep-grammars)
repo:

1. Set up a copy of the semgrep-grammars repo. Follow the instructions
   you may find, ensure the `tree-sitter-*` packages end up installed
   under `node_modules`.
2. Find the GitHub project for the tree-sitter grammar,
   typically named `tree-sitter-X` where `X` is the language name.
3. Add `tree-sitter-X`
   [as a submodule](https://github.com/returntocorp/semgrep-grammars/tree/master/src)
   like it's done already for other languages.
4. Create `src/semgrep-X/grammar.js` such that it extends the original
   grammar with the semgrep pattern constructs (`...`, `$X`). Again,
   imitate what's already done for other languages.
5. Write tests for the new syntax. Run `make && make test` from your
   `semgrep-X` folder until things work.
6. Create a symlink for your language under
   [`lang/`](https://github.com/returntocorp/semgrep-grammars/tree/master/lang).

Then, from the ocaml-tree-sitter repo, do the following:

1. Create a `lang/X` folder.
2. Add sample input programs for testing.
3. Add a collection of projects on which to run parsing stats.

Here's the file hierarchy for Ruby:

```shell
lang/ruby               # language name of the form [a-z][a-z0-9]*
├── examples            # sample input files, must end in '.src.'
│   ├── comment.rb.src
│   ├── ex1.rb.src
│   ├── ex2.rb.src
│   ├── hello.rb.src
│   └── poly.rb.src
├── extensions.txt      # standard name. Required for stats.
├── Makefile -> ../Makefile.common
└── projects.txt        # standard name. Required for stats.
```

To test a language in ocaml-tree-sitter:

1. Update the `semgrep-grammars` submodule to the desired branch.
2. Run `make` and `make install` from the project root to install
   the `ocaml-tree-sitter` executable and the runtime library.
3. Run `make` and `make test` from the language's folder.

The following sequence of commands is typical:
```bash
$ make && make install
$ cd lang/csharp
$ make
$ make test
```

Troubleshooting
--

Various errors can occur along the way.

Compilation errors in C or C++ are usually due to a missing source
file `scanner.c` or `scanner.cc`, or a grammar with a name that
doesn't match the name inside the scanner file. Javascript files may
also be missing, in particular in the case of grammars that extend
existing grammars such as C++ for C or TypeScript for
JavaScript. Check for `require()` calls in `grammar.js` and learn how
this NodeJS primitive resolves paths.

There may also be errors when generating or compiling
OCaml code. These are likely bugs in ocaml-tree-sitter and they should
be reported or fixed right away.

Here are some known types of parsing errors:

* A syntax error. The input program is in the wrong syntax or uses a
  recent feature that's not supported yet: `make test` or directly the
  `parse_X` program will show the tree produced by tree-sitter with
  one or more `ERROR` nodes.
* A "reparsing" error. It's an error generated after the first
  successful parsing pass by the tree-sitter parser, during the
  reparsing pass by the OCaml code performed by the generated
  `Parse.ml` file.  The error message should tell you something like
  "cannot interpret tree-sitter's output", with details on what code
  failed to match what pattern. This is most likely a bug in
  ocaml-tree-sitter.
* A segmentation fault. This could be due to a bug in the
  OCaml/tree-sitter C bindings and should be fixed. A simple test case
  that reproduces the problem would be nice.
  See https://github.com/returntocorp/ocaml-tree-sitter/issues/65

Parsing errors that are due
to an incomplete or incorrect grammar should be recorded, and
eventually reported and/or fixed in the upstream project.
We keep failing test cases in a `fail/` folder, preferably in the form
of the minimal program suitable for a bug report, with a comment
describing what was expected and what's going on.

Legal concerns
--

Be thankful for the authors of the original code, keep clearly visible
license notices, and make it easy to get back to the original projects:

* Group imported files by origin, preferably in the same folder with a
  `LICENSE` file. Typically, code generated from third-party
  tree-sitter grammars must be distributed with a copy of the license
  (read the licencing terms).
* For sample input in `examples/`, consider Public Domain ("The
  Unlicense") files or write your own, for simplicity.
  [GitHub Search](https://github.com/search/advanced)
  allows you to filter projects by license and by programming language.

Statistics
--

From a language's folder such as `lang/csharp`, two targets are
available to exercise the generated parser:

* `make test`: runs on `examples/*.src`
* `make stat`: downloads the code specified in `projects.txt` and
  parses the files whose extension matches those in `extensions.txt`,
  reporting parsing success in the form of a CSV file.

For gathering a good test corpus, you can use
[GitHub Search](https://github.com/search/advanced). Filter by
programming language and use a constraint to select large projects, such
as "> 100 forks". Collect the repository URLs and put them into
`projects.txt`.
