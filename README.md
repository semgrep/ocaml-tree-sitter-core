# project-reason-tree-sitter

The goal of this project is to write code to convert the definition
of an arithmetic grammar (in tests/arithmetic/grammar.json) into
the definition of an Abstract Syntax tree (AST) for arithmetic expressions
(see tests/arithmetic/ast_arithmetic.re for the expected output). This
AST definition can be automatically derived from the grammar.

The tests/arithmetic/grammar.json file does not use a traditional
format to define a grammar (e.g., a BNF grammar using the yacc syntax).
Instead, it uses a particuliar format (see the Context section below). 
It is derived from tests/arithmetic/grammar.js which is easier to read 
(but harder to analyze). 
See http://tree-sitter.github.io/tree-sitter/creating-parsers#the-grammar-dsl 
if you need to understand the format of grammar.js (which itself
will help to understand the format of grammar.json).

## Main problem

To test your code, run: 
```bash
./_build/default/bin/main_codegen.exe -codegen_types tests/arithmetic/grammar.json > tests/arithmetic/ast_arithmetic_output.re
```
and compare your result in tests/arithmetic/ast_arithmetic_output.re with
the expeced output in tests/arithmetic/ast_arithmetic.re.
Your result does not have to match exactly tests/arithmetic/ast_arithmetic.re,
but it should compile, and it should be mostly equivalent to
tests/arithmetic/ast_arithmetic.re.

The code you have to implement is mostly in lib/codegen_types.re.

## Hint

Because the format of the grammar in grammar.json allows nested
alternatives, it can be difficult to generate directly from the
grammar.json the reason type definitions. You could find useful to
define an intermediate ast_normalized_grammar.re that would be closer
to what reason can accept for type definitions.

## Bonus

As a bonus, you can generate the type definitions in a certain order,
from the toplevel types (e.g., 'program') to its leaves (e.g., 'number')
as done in tests/arithmetic/ast_arithmetic.re. You will need
to perform a topological sort of the type dependencies to do so.

## Context 

The tests/arithmetic/grammar.json file is part of the tree-sitter project
https://github.com/tree-sitter/tree-sitter. tree-sitter is a parser
generator (similar to yacc), which takes as input a grammar.js file
(e.g., tests/arithmetic/grammar.js). From this grammar.js file it
can generate a JSON file defining the same grammar but that is easier
to analyze (e.g., tests/arithmetic/grammar.json) and from this file
it can generate a parser for this grammar in C. 

Note that you do not need to understand or use tree-sitter for this project.
We just use the same format for the grammar definition (grammar.json).

## What we are looking for:

* Comfort with the language of choice: e.g. json parsing and matching should be easily understood
* Grasp of grammar, abstract datatypes, polymorphic types
* Test driven development
* Communication of complex graph algorithms like recursive top-down walk
* Good solution involves use of intermediate normalized AST definition


## Installation from source

To compile the code, you first need to [install OCaml](https://opam.ocaml.org/doc/Install.html) and its
package manager OPAM.
On macOS, it should simply consist in doing:

```bash
brew install opam
opam init
opam switch create 4.07.1
opam switch 4.07.1
eval $(opam env)
```

Once OPAM is installed, you need to install
the OCaml frontend reason, and the build system dune:

```bash
opam install reason
opam install dune
```

Then you can compile the program with:

```bash
dune build
```

## Run

Then to test on a file, for example tests/arithmetic/grammar.json
run:

```bash
./_build/default/bin/main_codegen.exe -parse_grammar tests/arithmetic/grammar.json
...
```

## Development Environment

You can use Visual Studio Code (vscode) to edit the code.
The [reason-vscode](https://marketplace.visualstudio.com/items?itemName=jaredly.reason-vscode) Marketplace extension adds support for OCaml/Reason.

The OCaml and Reason IDE extension by David Morrison is another valid
extension, but it seems not as actively maintained as reason-vscode.

The source contains also a .vscode/ directory at its root
containing a task file to automatically build the code from vscode.

Note that dune and ocamlmerlin must be in your PATH for vscode to correctly
build and provide cross-reference on the code. In case of problems, do:

```bash
cd /path/to/here
eval $(opam env)
dune        --version # just checking dune is in your PATH
ocamlmerlin -version  # just checking ocamlmerlin is in your PATH
code .
```

## Debugging code

Set the OCAMLRUNPARAM environment variable to 'b' for backtrace. 
You will get better backtrace information when an exception is thrown.

```bash
export OCAMLRUNPARAM=b
```
