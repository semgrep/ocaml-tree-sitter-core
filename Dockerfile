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

FROM ocaml/opam:debian-ocaml-5.4

# Slow steps that mostly download and build external stuff.
RUN sudo apt-get update

# libclang needed for rust bindgen
RUN sudo apt-get install -y rustup libclang-dev
RUN rustup default stable
RUN rustup update


WORKDIR /home/opam/ocaml-tree-sitter

COPY --chown=opam:opam scripts scripts

RUN ./scripts/setup-node

COPY --chown=opam:opam dune-project dune-project
COPY --chown=opam:opam tree-sitter-version tree-sitter-version

RUN ./scripts/setup-opam

COPY --chown=opam:opam dune dune

# Copy the rest, which changes often.
COPY --chown=opam:opam . .

# 'opam exec -- CMD' sets environment variables (PATH etc.) and runs
# command CMD in this environment.
# This is equivalent to 'eval $(opam env)' which normally goes into
# ~/.bashrc or similar.
#
RUN opam exec -- dune build --verbose
RUN opam exec -- dune build @install
RUN opam exec -- dune runtest --verbose
