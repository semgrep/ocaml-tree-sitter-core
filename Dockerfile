#
# Reference workflow for building and testing ocaml-tree-sitter.
#
# Run with:
#
#   docker build -t ocaml-tree-sitter .
#
# Enter the resulting container with:
#
#   docker run -it ocaml-tree-sitter
#

FROM ocaml/opam2:debian-stable

COPY --chown=opam:opam scripts /home/opam/ocaml-tree-sitter/scripts
COPY --chown=opam:opam Makefile /home/opam/ocaml-tree-sitter/Makefile
WORKDIR /home/opam/ocaml-tree-sitter

# hadolint ignore=DL3004
RUN sudo chown opam:opam .

# Slow steps that mostly download and build external stuff.
RUN ./scripts/setup-node
RUN ./scripts/setup-opam
COPY --chown=opam:opam configure /home/opam/ocaml-tree-sitter/configure
RUN opam exec -- ./configure
COPY --chown=opam:opam tree-sitter.opam /home/opam/ocaml-tree-sitter/tree-sitter.opam
RUN opam exec -- make setup

# Copy the rest, which changes often.
COPY --chown=opam:opam . /home/opam/ocaml-tree-sitter

# 'opam exec -- CMD' sets environment variables (PATH etc.) and runs
# command CMD in this environment.
# This is equivalent to 'eval $(opam env)' which normally goes into
# ~/.bashrc or similar.
#
RUN opam exec -- make
RUN opam exec -- make install
RUN opam exec -- make test
