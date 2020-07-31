How to add support for a new language
==

These instructions are likely to change as we add more languages and
we face maintenance and patching issues.

1. Find and clone the GitHub project hosting the tree-sitter grammar,
   typically named `tree-sitter-X` where `X` is the language name.
2. Copy the files in the expected folders of ocaml-tree-sitter,
   with the expected names.
3. Make manual adjustments.
4. Add a sample input program for testing.
5. Add a collection of projects on which to run parsing stats.

Here's the file hierarchy for C♯:

```shell
lang/csharp            # language name of the form [a-z][a-z0-9]*
├── examples
│   └── ConvexHull.cs.src  # sample input, must end in '.src.'
├── extensions.txt     # standard name. Required for stats.
├── grammar.js -> orig/grammar.js  # required. Doesn't have to be a symlink.
├── Makefile           # must include ../Makefile.common
└── orig
│   ├── grammar.js     # standard name. Required. May require other js files.
│   ├── LICENSE        # required
│   └── scanner.c      # standard name. Optional. Can also be 'scanner.cc'.
└── projects.txt       # standard name. Required for stats.
```

The most important files, which are copied from the tree-sitter-X
project, are `grammar.js` and when present, `scanner.c` or
`scanner.cc`. They contain the sources that define the parser
implementation. They will be converted into a large C file `parser.c`
by `tree-sitter generate`.

To test a language:

1. Run `make` and `make install` from the project root to install
   the `ocaml-tree-sitter` executable and the runtime library.
2. Run `make` and `make test` from the language's folder.

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
  `LICENSE` file.
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
