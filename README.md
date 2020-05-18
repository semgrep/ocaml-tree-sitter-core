# ocaml-tree-sitter
Generate OCaml code to read tree-sitter Concrete Syntax Trees and convert
them to OCaml-defined ASTs.

## Installation from source

To compile it, you first need to [install OCaml](https://opam.ocaml.org/doc/Install.html) and its
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

You can use Visual Studio Code (vscode) to edit the code of sgrep.
The [reason-vscode](https://marketplace.visualstudio.com/items?itemName=jaredly.reason-vscode) Marketplace extension adds support for OCaml/Reason.

The OCaml and Reason IDE extension by David Morrison is another valid
extension, but it seems not as actively maintained as reason-vscode.

The source of sgrep contains also a .vscode/ directory at its root
containing a task file to automatically build sgrep from vscode.

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

## Data flow

For a given target language X, the following steps apply:

1. tree-sitter: `grammar.js` → `grammar.json`
2. tree-sitter: `grammar.json` → C source
3. cc: C source → parser1
4. ocaml-tree-sitter: `grammar.json` → OCaml source
5. dune: OCaml source → parser2 (testing only)
6. parser1+parser2: X source → X AST dump (testing only)

Most of the code in this project is concerned with step 4,
i.e. generating OCaml code to take over parsing from parsers generated
by tree-sitter.

Steps 5 and 6 are about creating and using a standalone parser for
testing purposes. In the semgrep application, the generated OCaml code
will be used as a library.

Steps 1 to 3 invoke tree-sitter and a C compiler.
The grammars we want to use eventually are provided to us as
`grammar.js`. For testing purposes, we like to work directly
with `grammar.json`.
