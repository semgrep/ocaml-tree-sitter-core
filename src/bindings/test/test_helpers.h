/*
   Shared definitions for C test stubs.

   These struct layouts must match src/bindings/lib/bindings.c.
*/

#ifndef TEST_HELPERS_H
#define TEST_HELPERS_H

#include <tree_sitter/api.h>

#include <caml/alloc.h>
#include <caml/custom.h>
#include <caml/memory.h>
#include <caml/mlvalues.h>

typedef struct _parser {
  TSParser *parser;
} parser_W;

typedef struct _tree {
  TSTree *tree;
} tree_W;

#endif
