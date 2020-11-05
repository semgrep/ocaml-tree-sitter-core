# How to add support for a new language

## Submodules Overview

There are quite a few github repositories involved in porting a language. 
Here is a basic tree diagram that describes how they are linked.

``` shell
.
└── semgrep
    ├── ocaml-tree-sitter
    │   └── semgrep-grammars
    └── semgrep-core
        ├── ocaml-tree-sitter-lang
        └── pfff
```

* One good thing to note is that ocaml-tree-sitter-lang actually only contains auto-generated
  code. This auto-generated code is created by ocaml-tree-sitter. 

## Setup

As a model, you can use the existing setup for `ruby` or `javascript`. Our
most complicated setup is for `typescript` and `tsx`.

First install tree-sitter-cli and npx following 
[this doc](https://github.com/returntocorp/ocaml-tree-sitter/blob/f5b29e4198952233833cd989d35030baad7210b0/doc/node-setup.md).

## semgrep-grammars

Extend the language with semgrep pattern syntax in the
[semgrep-grammars](https://github.com/returntocorp/semgrep-grammars)
repo. Follow the instructions in [semgrep-grammars](https://github.com/returntocorp/semgrep-grammars)
under `Language-porting Instructions`.

## ocaml-tree-sitter

From the ocaml-tree-sitter repo, do the following:

1. Create a `lang/X` folder.
2. Make an examples directory. Inside the directory, 
   create a simple `hello-world` program for the language you are porting. 
   Name the program `hello-world.<ext>.src`.
3. Now make a file called `extensions.txt` and input all the language extensions
   (.rb, .kt, etc) for your language in the file.
4. Create a file called `fyi.list` with all the information files, such as
    `semgrep-grammars/src/tree-sitter-X/LICENSE`,
    `semgrep-grammars/src/tree-sitter-X/grammar.js`,
    `semgrep-grammars/src/semgrep-X/grammar.js`, etc.
   to bundle with the final OCaml/C project.
5. Link the Makefile.common to a Makefile in the directory with:
   `ln -s ../Makefile.common Makefile`
6. Create a test corpus. You can do this by:
   * Running `scripts/most-starred-for-language.py` in order to gather projects 
     on which to run parsing stats. Run with the following command:
     `python scripts/most-starred-for-language.py <lang> <github_username> <api_key>`
   * Using github advanced search to find the most starred or most forked repositories.
7. Copy the generated `projects.txt` file into the `lang/X` directory.
8. Add in extra projects and extra input sets as you see necessary.

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
├── fyi.list            # list of informational files to copy. Recommended.
├── Makefile -> ../Makefile.common
└── projects.txt        # standard name. Required for stats.
```

To test a language in ocaml-tree-sitter:

1. Update the `semgrep-grammars` submodule to the desired branch.
2. To ensure that the language is installed correctly in the newly pulled
   `semgrep-grammars` repository, run `make setup` and `make` in `semgrep-grammars`.
3. Run `make` and `make install` from the `ocaml-tree-sitter` (the root) to install
   the `ocaml-tree-sitter` executable and the runtime library.
4. Run `make` and `make test` from the language's folder.

The following sequence of commands is typical in the `ocaml-tree-sitter` repository:
```bash
$ cd lang/semgrep-grammars
$ make setup
$ make
$ cd ../..
$ make && make install
$ cd lang/csharp
$ make
$ make test
```

### The `fyi.list` file

The `fyi.list` file was created to specify informational files that
should accompany the generated files. These files are typically:

* the source grammar, most often a single `grammar.js` file.
* the licensing conditions usually specified in a `LICENSE` file.

Example:

```
# Comments are allowed on their own line.
# Blank lines are ok.

# Each path is relative to ocaml-tree-sitter/lang
semgrep-grammars/src/tree-sitter-ruby/LICENSE
semgrep-grammars/src/tree-sitter-ruby/grammar.js
semgrep-grammars/src/semgrep-ruby/grammar.js
```

The files listed in `fyi.list` end up in a `fyi` folder in
ocaml-tree-sitter-lang. For example,
[see `ruby/fyi`](https://github.com/returntocorp/ocaml-tree-sitter-lang/tree/master/ruby).

### Statistics

From a language's folder such as `lang/csharp`, two targets are
available to exercise the generated parser:

* `make test`: runs on `examples/*.src`
* `make stat`: downloads the code specified in `projects.txt` and
  parses the files whose extension matches those in `extensions.txt`,
  reporting parsing success in the form of a CSV file.

*** WARNING ***
If you are using `make stat` on OSX, OSX recently updated grep so that the 
installed version does not include the -P option used in the script. In order to make 
this work, run
`brew install grep`
and export the path to the new grep with:
`PATH="/usr/local/opt/grep/libexec/gnubin:$PATH"`.

For gathering a good test corpus, you can use
[GitHub Search](https://github.com/search/advanced) or the script
provided in `scripts/most-starred-for-language.py`. For github searches, filter by
programming language and use a constraint to select large projects, such
as "> 100 forks". Collect the repository URLs and put them into
`projects.txt`.

### Auto-Generating Parsing Code

After you have pushed your ocaml-tree-sitter changes to the main branch, do the following:
1. In `ocaml-tree-sitter/lang/Makefile`, add language under 'SUPPORTED_LANGUAGES' and 'STAT_LANGUAGES'.
2. In `ocaml-tree-sitter/lang` directory, run `./release X`. This will automatically 
   add code for parsing to `ocaml-tree-sitter-lang`. 

### Troubleshooting

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

## pfff

Now you need to update pfff, as the generic AST is defined in pfff and
you will need to specify some details in order to start filling out 
the auto-generated file.

Look under **Adding a Language** in [pfff](https://github.com/returntocorp/pfff/blob/develop/README.md)
for step-by-step instructions.

## semgrep-core

After pfff has been updated, you need to add these changes into semgrep-core. 
Follow the instructions specified in `semgrep-core/docs/port-language.md`.

## Legal concerns

Be thankful for the authors of the original code, keep clearly visible
license notices, and make it easy to get back to the original projects:

* Make sure to preserve the `LICENSE` files. This should be listed in
  the `fyi.list` file.
* For sample input in `examples/`, consider Public Domain ("The
  Unlicense") files or write your own, for simplicity.
  [GitHub Search](https://github.com/search/advanced)
  allows you to filter projects by license and by programming language.

## See also

[How to upgrade the grammar for a language](updating-a-grammar.md)
