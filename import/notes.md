Notes about the r2c assignment
==

Most of the code should be self-explanatory. I took care of leaving
TODO notes in the places where more work would be needed in a
real-world scenario.

Building and testing
--

My work was done in OCaml, using dune like the starter code.
Required opam packages:

```
$ opam install atdgen tsort
```

I shortened the name of the executable to `prts`.

To build and test:
```
$ make
$ make test
```

The tests should be successful. The output is compared to the expected
output. We have two tests:

* the original "arithmetic" grammar
* the json grammar which I took from the tree-sitter-json project

Design and implementation notes
--

I used atdgen for parsing the original json specification. In theory
it could allow us to convert a parsed grammar.json back to json without
loss. Some non-negligible helper code had to be written due to the use
of variants. It would have to be completed to allow converting an AST
from OCaml back to JSON. This is the code in `Json_rule_adapter.ml`
The advantage here is that we have an OCaml type definition that
accurately reflects that original data without loss. Those definitions
are in `Tree_sitter.atd`, and the corresponding OCaml type definition
and derived code can be found in `_build`.

The intermediate tree is defined in `AST_grammar`. Some of the
constructs from the original grammar have been dropped, and we perform
a normalization pass in which alternatives and sequences are
flattened. The use of polymorphic variants in the output allows us to
not have to extract and name anonymous alternatives.
See `tests/json/grammar_refmt.re` for an example of such output.

The third step of the pipeline is code generation. This is the `Codegen`
module. It produces a roughly indented output, which can be checked and
reformatted using `refmt`. I got a bit creative with the
`Protect_ident` module, since we needed a way to turn `object` into
`object_` to make it a valid Reason identifier in the json test. I
wrote a system for avoiding conflicts. I didn't test it much. At least
it seem to work minimally.

Schedule
--

```
Wednesday 05/06
17:30 getting started
18:00 pause
18:15 resume
20:00 stopping for the day

Thursday 05/07
09:00 resume
~~ write code ~~
13:00 pause
13:40 resume
~~ first end-to-end compilable and runnable program ~~
15:30
~~ topological sort ~~
~~ add big sample grammar to test suite and fix new problems ~~
~~ wrap up ~~
20:55 end
```
