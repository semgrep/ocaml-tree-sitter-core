/*
  Copyright (c) 2019 onivim

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all
  copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE.
*/

/// @file bindings.c
/// @brief OCaml FFI bindings for the tree-sitter C API (v0.22.6).
///
/// Safety model:
/// - Heap-allocated tree-sitter objects (TSParser*, TSTree*, TSQuery*,
///   TSQueryCursor*, TSLookaheadIterator*) are stored as pointers in OCaml
///   custom blocks with GC finalizers. Finalizers NULL the pointer after
///   freeing to prevent double-free.
/// - TSNode and TSTreeCursor are stored by value in custom blocks.
///   TSTreeCursor has a finalizer; TSNode does not.
/// - TSNode contains a raw pointer to its parent tree. Callers must ensure
///   the tree outlives any nodes obtained from it.
/// - Functions that can return NULL use OCaml option types.
/// - The parse read callback roots the OCaml closure via CAMLparam and copies
///   returned string data into a C buffer to avoid GC pointer invalidation.

#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include <tree_sitter/api.h>

#include <caml/alloc.h>
#include <caml/callback.h>
#include <caml/custom.h>
#include <caml/fail.h>
#include <caml/memory.h>
#include <caml/mlvalues.h>
#include <caml/threads.h>

// ============================================================================
// Accessor macros
// ============================================================================

/// Dereference the TSParser* stored at the start of a custom block's data.
#define TSParser_val(v) (*(TSParser **)Data_custom_val(v))

/// Dereference the TSTree* stored at the start of a custom block's data.
#define TSTree_val(v) (*(TSTree **)Data_custom_val(v))

/// Pointer to the TSNode stored by value inside a custom block.
#define TSNode_val(v) ((TSNode *)Data_custom_val(v))

/// Pointer to the TSTreeCursor stored by value inside a custom block.
#define TSTreeCursor_val(v) ((TSTreeCursor *)Data_custom_val(v))

/// Dereference the TSQuery* stored at the start of a custom block's data.
#define TSQuery_val(v) (*(TSQuery **)Data_custom_val(v))

/// Dereference the TSQueryCursor* stored at the start of a custom block's data.
#define TSQueryCursor_val(v) (*(TSQueryCursor **)Data_custom_val(v))

/// Dereference the const TSLanguage* stored in a custom block's data.
#define TSLanguage_val(v) (*(const TSLanguage **)Data_custom_val(v))

/// Dereference the TSLookaheadIterator* stored in a custom block's data.
#define TSLookaheadIterator_val(v) (*(TSLookaheadIterator **)Data_custom_val(v))

/// OCaml representation of None.
#define Val_none Val_int(0)

// ============================================================================
// Finalizers
// ============================================================================

static void finalize_parser(value v) {
  TSParser *p = TSParser_val(v);
  if (p) {
    ts_parser_delete(p);
    TSParser_val(v) = NULL;
  }
}

static void finalize_tree(value v) {
  TSTree *t = TSTree_val(v);
  if (t) {
    ts_tree_delete(t);
    TSTree_val(v) = NULL;
  }
}

static void finalize_tree_cursor(value v) {
  ts_tree_cursor_delete(TSTreeCursor_val(v));
}

static void finalize_query(value v) {
  TSQuery *q = TSQuery_val(v);
  if (q) {
    ts_query_delete(q);
    TSQuery_val(v) = NULL;
  }
}

static void finalize_query_cursor(value v) {
  TSQueryCursor *c = TSQueryCursor_val(v);
  if (c) {
    ts_query_cursor_delete(c);
    TSQueryCursor_val(v) = NULL;
  }
}

static void finalize_language(value v) {
  const TSLanguage *lang = TSLanguage_val(v);
  if (lang) {
    ts_language_delete(lang);
    TSLanguage_val(v) = NULL;
  }
}

static void finalize_lookahead_iterator(value v) {
  TSLookaheadIterator *it = TSLookaheadIterator_val(v);
  if (it) {
    ts_lookahead_iterator_delete(it);
    TSLookaheadIterator_val(v) = NULL;
  }
}

// ============================================================================
// Node comparison and hashing (backs OCaml structural equality/hashing)
// ============================================================================

static int compare_node(value v1, value v2) {
  TSNode a = *TSNode_val(v1);
  TSNode b = *TSNode_val(v2);
  if (ts_node_eq(a, b))
    return 0;
  if (a.id < b.id)
    return -1;
  return 1;
}

static intnat hash_node(value v) { return (intnat)(TSNode_val(v)->id); }

// ============================================================================
// Custom operations tables
// ============================================================================

static struct custom_operations parser_ops = {
    .identifier = "octs.parser",
    .finalize = finalize_parser,
    .compare = custom_compare_default,
    .hash = custom_hash_default,
    .serialize = custom_serialize_default,
    .deserialize = custom_deserialize_default,
};

static struct custom_operations tree_ops = {
    .identifier = "octs.tree",
    .finalize = finalize_tree,
    .compare = custom_compare_default,
    .hash = custom_hash_default,
    .serialize = custom_serialize_default,
    .deserialize = custom_deserialize_default,
};

static struct custom_operations node_ops = {
    .identifier = "octs.node",
    .finalize = custom_finalize_default,
    .compare = compare_node,
    .hash = hash_node,
    .serialize = custom_serialize_default,
    .deserialize = custom_deserialize_default,
};

static struct custom_operations tree_cursor_ops = {
    .identifier = "octs.tree_cursor",
    .finalize = finalize_tree_cursor,
    .compare = custom_compare_default,
    .hash = custom_hash_default,
    .serialize = custom_serialize_default,
    .deserialize = custom_deserialize_default,
};

static struct custom_operations query_ops = {
    .identifier = "octs.query",
    .finalize = finalize_query,
    .compare = custom_compare_default,
    .hash = custom_hash_default,
    .serialize = custom_serialize_default,
    .deserialize = custom_deserialize_default,
};

static struct custom_operations query_cursor_ops = {
    .identifier = "octs.query_cursor",
    .finalize = finalize_query_cursor,
    .compare = custom_compare_default,
    .hash = custom_hash_default,
    .serialize = custom_serialize_default,
    .deserialize = custom_deserialize_default,
};

static struct custom_operations language_ops = {
    .identifier = "octs.language",
    .finalize = finalize_language,
    .compare = custom_compare_default,
    .hash = custom_hash_default,
    .serialize = custom_serialize_default,
    .deserialize = custom_deserialize_default,
};

static struct custom_operations lookahead_iterator_ops = {
    .identifier = "octs.lookahead_iterator",
    .finalize = finalize_lookahead_iterator,
    .compare = custom_compare_default,
    .hash = custom_hash_default,
    .serialize = custom_serialize_default,
    .deserialize = custom_deserialize_default,
};

// ============================================================================
// Helpers: type conversions between OCaml values and tree-sitter structs
// ============================================================================

/// Extract a TSPoint from an OCaml point = { row : int; column : int }.
/// Does not allocate.
static inline TSPoint point_val(value v /* : point */) {
  TSPoint p = {
      .row = Int_val(Field(v, 0)),
      .column = Int_val(Field(v, 1)),
  };
  return p;
}

/// Allocate an OCaml point record from a TSPoint. May trigger GC.
static value val_of_point(TSPoint p) {
  CAMLparam0();
  CAMLlocal1(v);
  v = caml_alloc(2, 0);
  Store_field(v, 0, Val_int(p.row));
  Store_field(v, 1, Val_int(p.column));
  CAMLreturn(v);
}

/// Extract a TSRange from an OCaml range record. Does not allocate.
/// range = { start_point : point; end_point : point;
///           start_byte : int; end_byte : int }
static inline TSRange range_val(value v /* : range */) {
  TSRange r = {
      .start_point = point_val(Field(v, 0)),
      .end_point = point_val(Field(v, 1)),
      .start_byte = Int_val(Field(v, 2)),
      .end_byte = Int_val(Field(v, 3)),
  };
  return r;
}

/// Allocate an OCaml range record from a TSRange. May trigger GC.
static value val_of_range(TSRange r) {
  CAMLparam0();
  CAMLlocal3(v, v_sp, v_ep);
  v_sp = val_of_point(r.start_point);
  v_ep = val_of_point(r.end_point);
  v = caml_alloc(4, 0);
  Store_field(v, 0, v_sp);
  Store_field(v, 1, v_ep);
  Store_field(v, 2, Val_int(r.start_byte));
  Store_field(v, 3, Val_int(r.end_byte));
  CAMLreturn(v);
}

/// Extract a TSInputEdit from an OCaml input_edit record. Does not allocate.
/// input_edit = { start_byte : int; old_end_byte : int; new_end_byte : int;
///                start_point : point; old_end_point : point;
///                new_end_point : point }
static inline TSInputEdit input_edit_val(value v /* : input_edit */) {
  TSInputEdit e = {
      .start_byte = Int_val(Field(v, 0)),
      .old_end_byte = Int_val(Field(v, 1)),
      .new_end_byte = Int_val(Field(v, 2)),
      .start_point = point_val(Field(v, 3)),
      .old_end_point = point_val(Field(v, 4)),
      .new_end_point = point_val(Field(v, 5)),
  };
  return e;
}

/// Wrap a value in Some(_). May trigger GC.
static value val_some(value v) {
  CAMLparam1(v);
  CAMLlocal1(some);
  some = caml_alloc(1, 0);
  Store_field(some, 0, v);
  CAMLreturn(some);
}

/// Allocate an OCaml node custom block from a TSNode. May trigger GC.
static value alloc_node(TSNode node) {
  CAMLparam0();
  CAMLlocal1(v);
  v = caml_alloc_custom(&node_ops, sizeof node, 0, 1);
  memcpy(Data_custom_val(v), &node, sizeof node);
  CAMLreturn(v);
}

/// Allocate an OCaml tree custom block. Takes ownership of the pointer. May
/// trigger GC.
static value alloc_tree(TSTree *tree) {
  CAMLparam0();
  CAMLlocal1(v);
  v = caml_alloc_custom(&tree_ops, sizeof(TSTree *), 0, 1);
  TSTree_val(v) = tree;
  CAMLreturn(v);
}

/// Allocate an OCaml language custom block. Calls ts_language_copy to take a
/// reference. May trigger GC.
static value alloc_language(const TSLanguage *lang) {
  CAMLparam0();
  CAMLlocal1(v);
  // safety: ts_language_copy increments the refcount (or is a no-op for
  // statically-allocated grammars). The finalizer calls ts_language_delete.
  const TSLanguage *copy = ts_language_copy(lang);
  v = caml_alloc_custom(&language_ops, sizeof(const TSLanguage *), 0, 1);
  TSLanguage_val(v) = copy;
  CAMLreturn(v);
}

// ============================================================================
// Parser
// ============================================================================

/// val parser_new : unit -> parser
CAMLprim value octs_parser_new(value v_unit /* : unit */) {
  CAMLparam1(v_unit);
  CAMLlocal1(v);
  TSParser *parser = ts_parser_new();
  v = caml_alloc_custom(&parser_ops, sizeof(TSParser *), 0, 1);
  TSParser_val(v) = parser;
  CAMLreturn(v);
}

/// val parser_delete : parser -> unit
CAMLprim value octs_parser_delete(value v_parser /* : parser */) {
  TSParser *p = TSParser_val(v_parser);
  if (p) {
    ts_parser_delete(p);
    TSParser_val(v_parser) = NULL;
  }
  return Val_unit;
}

/// val parser_set_language : parser -> language -> bool
CAMLprim value octs_parser_set_language(value v_parser /* : parser */,
                                        value v_lang /* : language */) {
  // safety: no allocation, so both values are stable.
  return Val_bool(
      ts_parser_set_language(TSParser_val(v_parser), TSLanguage_val(v_lang)));
}

/// val parser_language : parser -> language
CAMLprim value octs_parser_language(value v_parser /* : parser */) {
  CAMLparam1(v_parser);
  const TSLanguage *lang = ts_parser_language(TSParser_val(v_parser));
  CAMLreturn(alloc_language(lang));
}

/// Context for the parse read callback. Stored on the C stack during parsing.
struct parse_ctx {
  value *read_fn; ///< Pointer to a CAMLparam-rooted OCaml closure.
  char *buf;      ///< Reusable buffer for string data copied from OCaml heap.
  size_t buf_cap; ///< Current capacity of buf.
  value exn;      ///< Stashed exception from callback, or 0 if none.
};

/// Read callback invoked by ts_parser_parse. Calls back into OCaml.
///
/// If the OCaml closure raises, we stash the exception and signal EOF
/// (bytes_read=0, return NULL) so tree-sitter returns control to
/// octs_parser_parse, which frees the buffer and re-raises.
static const char *parse_read_cb(void *payload, uint32_t byte_offset,
                                 TSPoint position, uint32_t *bytes_read) {
  struct parse_ctx *ctx = payload;
  *bytes_read = 0;

  // If a previous callback already raised, keep signalling EOF.
  if (ctx->exn != 0) {
    return NULL;
  }

  // safety: *ctx->read_fn is kept up-to-date by the GC because it points into
  // the CAMLparam roots block of the enclosing octs_parser_parse frame.
  // caml_callback3_exn roots the closure and arguments internally.
  value v_result /* : string option */ =
      caml_callback3_exn(*ctx->read_fn, Val_int(byte_offset),
                         Val_int(position.row), Val_int(position.column));

  if (Is_exception_result(v_result)) {
    // safety: stash the exception value (with the exception-result tag
    // stripped). octs_parser_parse will re-raise after cleanup.
    ctx->exn = Extract_exception(v_result);
    // safety: ctx->exn is reachable from the CAMLparam roots block in
    // octs_parser_parse (we store it into v_exn there after ts_parser_parse
    // returns), but between now and then no OCaml allocation occurs (we
    // signal EOF, tree-sitter does only C work, then returns). So the raw
    // value is safe to hold temporarily.
    return NULL;
  }

  if (Is_block(v_result)) {
    value v_str /* : string */ = Field(v_result, 0);
    size_t len = caml_string_length(v_str);
    // safety: copy the string data to a C-heap buffer before returning.
    // The OCaml string pointer from String_val may be invalidated by GC
    // on the next callback invocation. tree-sitter only borrows the returned
    // pointer until the next read call, so the buffer is safe.
    if (len > ctx->buf_cap) {
      free(ctx->buf);
      ctx->buf = malloc(len);
      ctx->buf_cap = len;
    }
    memcpy(ctx->buf, String_val(v_str), len);
    *bytes_read = (uint32_t)len;
    return ctx->buf;
  }
  return NULL;
}

/// val parser_parse :
///   parser -> tree option -> (int -> int -> int -> string option) ->
///     tree option
CAMLprim value octs_parser_parse(value v_parser /* : parser */,
                                 value v_old_tree /* : tree option */,
                                 value v_read_fn /* : read_function */) {
  CAMLparam3(v_parser, v_old_tree, v_read_fn);
  CAMLlocal1(v_result);

  TSParser *parser = TSParser_val(v_parser);
  TSTree *old_tree = NULL;
  if (Is_block(v_old_tree)) {
    // safety: Field(v_old_tree, 0) is the tree value inside Some(_).
    // v_old_tree is rooted by CAMLparam3.
    old_tree = TSTree_val(Field(v_old_tree, 0));
  }

  struct parse_ctx ctx = {
      // safety: &v_read_fn points into the caml__roots_block on the stack.
      // The GC updates v_read_fn through this roots block, so *ctx.read_fn
      // always holds the current (post-GC) value of the closure.
      .read_fn = &v_read_fn,
      .buf = NULL,
      .buf_cap = 0,
      .exn = 0,
  };

  TSInput input = {
      .payload = &ctx,
      .read = parse_read_cb,
      .encoding = TSInputEncodingUTF8,
  };

  TSTree *tree = ts_parser_parse(parser, old_tree, input);
  free(ctx.buf);

  // If the read callback stashed an exception, clean up and re-raise.
  // We are back in our own frame now, so longjmp from caml_raise is safe.
  if (ctx.exn != 0) {
    if (tree) {
      ts_tree_delete(tree);
    }
    // safety: between the callback stashing ctx.exn and here, no OCaml
    // allocation occurred (tree-sitter did only C work then returned),
    // so the raw value is still valid. caml_raise roots it internally.
    caml_raise(ctx.exn);
  }

  if (!tree) {
    CAMLreturn(Val_none);
  }
  v_result = alloc_tree(tree);
  CAMLreturn(val_some(v_result));
}

/// val parser_parse_string : parser -> string -> tree
/// @note Raises [Failure] if ts_parser_parse_string returns NULL (e.g. no
///       language set on the parser).
CAMLprim value octs_parser_parse_string(value v_parser /* : parser */,
                                        value v_source /* : string */) {
  CAMLparam2(v_parser, v_source);
  CAMLlocal1(v);

  TSParser *parser = TSParser_val(v_parser);
  // safety: extract pointer and length before any allocation. String_val
  // returns a pointer into the OCaml heap; caml_string_length is safe to
  // call on a rooted value. We pass both to ts_parser_parse_string which
  // does not call back into OCaml, so no GC can occur during the call.
  const char *source = String_val(v_source);
  uint32_t len = caml_string_length(v_source);

  TSTree *tree = ts_parser_parse_string(parser, NULL, source, len);
  if (!tree) {
    caml_failwith(
        "ts_parser_parse_string returned NULL (no language set on parser?)");
  }

  v = alloc_tree(tree);
  CAMLreturn(v);
}

/// val parser_reset : parser -> unit
CAMLprim value octs_parser_reset(value v_parser /* : parser */) {
  // safety: no allocation.
  ts_parser_reset(TSParser_val(v_parser));
  return Val_unit;
}

/// val parser_set_timeout_micros : parser -> int -> unit
CAMLprim value octs_parser_set_timeout_micros(value v_parser /* : parser */,
                                              value v_timeout /* : int */) {
  // safety: no allocation.
  ts_parser_set_timeout_micros(TSParser_val(v_parser), Int_val(v_timeout));
  return Val_unit;
}

/// val parser_timeout_micros : parser -> int
CAMLprim value octs_parser_timeout_micros(value v_parser /* : parser */) {
  // safety: no allocation.
  return Val_int(ts_parser_timeout_micros(TSParser_val(v_parser)));
}

/// val parser_set_included_ranges : parser -> range array -> bool
CAMLprim value octs_parser_set_included_ranges(
    value v_parser /* : parser */, value v_ranges /* : range array */) {
  CAMLparam2(v_parser, v_ranges);

  uint32_t count = Wosize_val(v_ranges);
  TSRange *ranges = NULL;
  if (count > 0) {
    ranges = malloc(count * sizeof *ranges);
    for (uint32_t i = 0; i < count; i++) {
      // safety: Field(v_ranges, i) reads from the rooted array. range_val
      // does not allocate, so the array is stable during the loop.
      ranges[i] = range_val(Field(v_ranges, i));
    }
  }

  bool ok =
      ts_parser_set_included_ranges(TSParser_val(v_parser), ranges, count);
  free(ranges);
  CAMLreturn(Val_bool(ok));
}

/// val parser_included_ranges : parser -> range array
CAMLprim value octs_parser_included_ranges(value v_parser /* : parser */) {
  CAMLparam1(v_parser);
  CAMLlocal2(v_arr, v_range);

  uint32_t count;
  // safety: the returned pointer is owned by the parser; do not free it.
  const TSRange *ranges =
      ts_parser_included_ranges(TSParser_val(v_parser), &count);

  v_arr = caml_alloc(count, 0);
  for (uint32_t i = 0; i < count; i++) {
    v_range = val_of_range(ranges[i]);
    Store_field(v_arr, i, v_range);
  }
  CAMLreturn(v_arr);
}

/// val parser_print_dot_graphs : parser -> int -> unit
CAMLprim value octs_parser_print_dot_graphs(value v_parser /* : parser */,
                                            value v_fd /* : int */) {
  // safety: no allocation.
  ts_parser_print_dot_graphs(TSParser_val(v_parser), Int_val(v_fd));
  return Val_unit;
}

// ============================================================================
// Tree
// ============================================================================

/// val tree_copy : tree -> tree
CAMLprim value octs_tree_copy(value v_tree /* : tree */) {
  CAMLparam1(v_tree);
  TSTree *copy = ts_tree_copy(TSTree_val(v_tree));
  CAMLreturn(alloc_tree(copy));
}

/// val tree_delete : tree -> unit
/// Explicitly free the tree. Safe to call multiple times (idempotent).
CAMLprim value octs_tree_delete(value v_tree /* : tree */) {
  TSTree *t = TSTree_val(v_tree);
  if (t) {
    ts_tree_delete(t);
    TSTree_val(v_tree) = NULL;
  }
  return Val_unit;
}

/// val tree_root_node : tree -> node
CAMLprim value octs_tree_root_node(value v_tree /* : tree */) {
  CAMLparam1(v_tree);
  TSNode node = ts_tree_root_node(TSTree_val(v_tree));
  CAMLreturn(alloc_node(node));
}

/// val tree_root_node_with_offset : tree -> int -> point -> node
CAMLprim value octs_tree_root_node_with_offset(
    value v_tree /* : tree */, value v_offset_bytes /* : int */,
    value v_offset_extent /* : point */) {
  CAMLparam3(v_tree, v_offset_bytes, v_offset_extent);
  TSPoint offset = point_val(v_offset_extent);
  TSNode node = ts_tree_root_node_with_offset(TSTree_val(v_tree),
                                              Int_val(v_offset_bytes), offset);
  CAMLreturn(alloc_node(node));
}

/// val tree_language : tree -> language
CAMLprim value octs_tree_language(value v_tree /* : tree */) {
  CAMLparam1(v_tree);
  const TSLanguage *lang = ts_tree_language(TSTree_val(v_tree));
  CAMLreturn(alloc_language(lang));
}

/// val tree_included_ranges : tree -> range array
CAMLprim value octs_tree_included_ranges(value v_tree /* : tree */) {
  CAMLparam1(v_tree);
  CAMLlocal2(v_arr, v_range);

  uint32_t count;
  // safety: ts_tree_included_ranges returns a malloc'd array; we must free it.
  TSRange *ranges = ts_tree_included_ranges(TSTree_val(v_tree), &count);

  v_arr = caml_alloc(count, 0);
  for (uint32_t i = 0; i < count; i++) {
    v_range = val_of_range(ranges[i]);
    Store_field(v_arr, i, v_range);
  }
  free(ranges);
  CAMLreturn(v_arr);
}

/// val tree_edit : tree -> input_edit -> tree
/// Returns a fresh copy of the tree with the edit applied.
CAMLprim value octs_tree_edit(value v_tree /* : tree */,
                              value v_edit /* : input_edit */) {
  CAMLparam2(v_tree, v_edit);
  CAMLlocal1(v_result);

  // safety: extract the edit (no allocation) and copy the tree before any
  // OCaml allocation invalidates v_tree.
  TSInputEdit edit = input_edit_val(v_edit);
  TSTree *copy = ts_tree_copy(TSTree_val(v_tree));
  ts_tree_edit(copy, &edit);

  v_result = alloc_tree(copy);
  CAMLreturn(v_result);
}

/// val tree_get_changed_ranges : tree -> tree -> range array
CAMLprim value octs_tree_get_changed_ranges(value v_old /* : tree */,
                                            value v_new /* : tree */) {
  CAMLparam2(v_old, v_new);
  CAMLlocal2(v_arr, v_range);

  uint32_t count;
  // safety: ts_tree_get_changed_ranges returns a malloc'd array; must free.
  TSRange *ranges =
      ts_tree_get_changed_ranges(TSTree_val(v_old), TSTree_val(v_new), &count);

  v_arr = caml_alloc(count, 0);
  for (uint32_t i = 0; i < count; i++) {
    v_range = val_of_range(ranges[i]);
    Store_field(v_arr, i, v_range);
  }
  free(ranges);
  CAMLreturn(v_arr);
}

/// val tree_print_dot_graph : tree -> int -> unit
CAMLprim value octs_tree_print_dot_graph(value v_tree /* : tree */,
                                         value v_fd /* : int */) {
  // safety: no allocation.
  ts_tree_print_dot_graph(TSTree_val(v_tree), Int_val(v_fd));
  return Val_unit;
}

// ============================================================================
// Node
// ============================================================================

/// val node_type : node -> string
CAMLprim value octs_node_type(value v_node /* : node */) {
  CAMLparam1(v_node);
  // safety: ts_node_type returns a pointer to static string data owned by
  // the grammar. We copy it before returning, and the copy is the only
  // allocation.
  const char *s = ts_node_type(*TSNode_val(v_node));
  CAMLreturn(caml_copy_string(s));
}

/// val node_symbol : node -> int
CAMLprim value octs_node_symbol(value v_node /* : node */) {
  // safety: no allocation.
  return Val_int(ts_node_symbol(*TSNode_val(v_node)));
}

/// val node_language : node -> language
CAMLprim value octs_node_language(value v_node /* : node */) {
  CAMLparam1(v_node);
  TSNode node = *TSNode_val(v_node);
  const TSLanguage *lang = ts_node_language(node);
  CAMLreturn(alloc_language(lang));
}

/// val node_grammar_type : node -> string
CAMLprim value octs_node_grammar_type(value v_node /* : node */) {
  CAMLparam1(v_node);
  const char *s = ts_node_grammar_type(*TSNode_val(v_node));
  CAMLreturn(caml_copy_string(s));
}

/// val node_grammar_symbol : node -> int
CAMLprim value octs_node_grammar_symbol(value v_node /* : node */) {
  // safety: no allocation.
  return Val_int(ts_node_grammar_symbol(*TSNode_val(v_node)));
}

/// val node_start_byte : node -> int
CAMLprim value octs_node_start_byte(value v_node /* : node */) {
  // safety: no allocation.
  return Val_int(ts_node_start_byte(*TSNode_val(v_node)));
}

/// val node_start_point : node -> point
CAMLprim value octs_node_start_point(value v_node /* : node */) {
  CAMLparam1(v_node);
  // safety: extract node by value before allocating.
  TSPoint p = ts_node_start_point(*TSNode_val(v_node));
  CAMLreturn(val_of_point(p));
}

/// val node_end_byte : node -> int
CAMLprim value octs_node_end_byte(value v_node /* : node */) {
  // safety: no allocation.
  return Val_int(ts_node_end_byte(*TSNode_val(v_node)));
}

/// val node_end_point : node -> point
CAMLprim value octs_node_end_point(value v_node /* : node */) {
  CAMLparam1(v_node);
  TSPoint p = ts_node_end_point(*TSNode_val(v_node));
  CAMLreturn(val_of_point(p));
}

/// val node_string : node -> string
/// @note The caller does not need to free the result; the OCaml GC manages it.
CAMLprim value octs_node_string(value v_node /* : node */) {
  CAMLparam1(v_node);
  CAMLlocal1(v);
  // safety: ts_node_string returns a malloc'd string; we copy to OCaml heap
  // then free.
  char *s = ts_node_string(*TSNode_val(v_node));
  v = caml_copy_string(s);
  free(s);
  CAMLreturn(v);
}

/// val node_is_null : node -> bool
CAMLprim value octs_node_is_null(value v_node /* : node */) {
  // safety: no allocation.
  return Val_bool(ts_node_is_null(*TSNode_val(v_node)));
}

/// val node_is_named : node -> bool
CAMLprim value octs_node_is_named(value v_node /* : node */) {
  // safety: no allocation.
  return Val_bool(ts_node_is_named(*TSNode_val(v_node)));
}

/// val node_is_missing : node -> bool
CAMLprim value octs_node_is_missing(value v_node /* : node */) {
  // safety: no allocation.
  return Val_bool(ts_node_is_missing(*TSNode_val(v_node)));
}

/// val node_is_extra : node -> bool
CAMLprim value octs_node_is_extra(value v_node /* : node */) {
  // safety: no allocation.
  return Val_bool(ts_node_is_extra(*TSNode_val(v_node)));
}

/// val node_has_changes : node -> bool
CAMLprim value octs_node_has_changes(value v_node /* : node */) {
  // safety: no allocation.
  return Val_bool(ts_node_has_changes(*TSNode_val(v_node)));
}

/// val node_has_error : node -> bool
CAMLprim value octs_node_has_error(value v_node /* : node */) {
  // safety: no allocation.
  return Val_bool(ts_node_has_error(*TSNode_val(v_node)));
}

/// val node_is_error : node -> bool
CAMLprim value octs_node_is_error(value v_node /* : node */) {
  // safety: no allocation.
  return Val_bool(ts_node_is_error(*TSNode_val(v_node)));
}

/// val node_parse_state : node -> int
CAMLprim value octs_node_parse_state(value v_node /* : node */) {
  // safety: no allocation.
  return Val_int(ts_node_parse_state(*TSNode_val(v_node)));
}

/// val node_next_parse_state : node -> int
CAMLprim value octs_node_next_parse_state(value v_node /* : node */) {
  // safety: no allocation.
  return Val_int(ts_node_next_parse_state(*TSNode_val(v_node)));
}

/// val node_parent : node -> node
CAMLprim value octs_node_parent(value v_node /* : node */) {
  CAMLparam1(v_node);
  // safety: extract node by value before allocating the result.
  TSNode node = *TSNode_val(v_node);
  CAMLreturn(alloc_node(ts_node_parent(node)));
}

/// val node_child_containing_descendant : node -> node -> node
CAMLprim value octs_node_child_containing_descendant(
    value v_node /* : node */, value v_descendant /* : node */) {
  CAMLparam2(v_node, v_descendant);
  TSNode node = *TSNode_val(v_node);
  TSNode descendant = *TSNode_val(v_descendant);
  CAMLreturn(alloc_node(ts_node_child_containing_descendant(node, descendant)));
}

/// val node_child : node -> int -> node
CAMLprim value octs_node_child(value v_node /* : node */,
                               value v_index /* : int */) {
  CAMLparam2(v_node, v_index);
  TSNode node = *TSNode_val(v_node);
  CAMLreturn(alloc_node(ts_node_child(node, Int_val(v_index))));
}

/// val node_field_name_for_child : node -> int -> string option
CAMLprim value octs_node_field_name_for_child(value v_node /* : node */,
                                              value v_index /* : int */) {
  CAMLparam2(v_node, v_index);
  CAMLlocal1(v_str);
  TSNode node = *TSNode_val(v_node);
  const char *name = ts_node_field_name_for_child(node, Int_val(v_index));
  if (!name) {
    CAMLreturn(Val_none);
  }
  v_str = caml_copy_string(name);
  CAMLreturn(val_some(v_str));
}

/// val node_child_count : node -> int
CAMLprim value octs_node_child_count(value v_node /* : node */) {
  // safety: no allocation.
  return Val_int(ts_node_child_count(*TSNode_val(v_node)));
}

/// val node_named_child : node -> int -> node
CAMLprim value octs_node_named_child(value v_node /* : node */,
                                     value v_index /* : int */) {
  CAMLparam2(v_node, v_index);
  TSNode node = *TSNode_val(v_node);
  CAMLreturn(alloc_node(ts_node_named_child(node, Int_val(v_index))));
}

/// val node_named_child_count : node -> int
CAMLprim value octs_node_named_child_count(value v_node /* : node */) {
  // safety: no allocation.
  return Val_int(ts_node_named_child_count(*TSNode_val(v_node)));
}

/// val node_child_by_field_name : node -> string -> node
CAMLprim value octs_node_child_by_field_name(value v_node /* : node */,
                                             value v_name /* : string */) {
  CAMLparam2(v_node, v_name);
  // safety: extract node and string data before any allocation.
  TSNode node = *TSNode_val(v_node);
  const char *name = String_val(v_name);
  uint32_t len = caml_string_length(v_name);
  CAMLreturn(alloc_node(ts_node_child_by_field_name(node, name, len)));
}

/// val node_child_by_field_id : node -> int -> node
CAMLprim value octs_node_child_by_field_id(value v_node /* : node */,
                                           value v_id /* : int */) {
  CAMLparam2(v_node, v_id);
  TSNode node = *TSNode_val(v_node);
  CAMLreturn(alloc_node(ts_node_child_by_field_id(node, Int_val(v_id))));
}

/// val node_next_sibling : node -> node
CAMLprim value octs_node_next_sibling(value v_node /* : node */) {
  CAMLparam1(v_node);
  TSNode node = *TSNode_val(v_node);
  CAMLreturn(alloc_node(ts_node_next_sibling(node)));
}

/// val node_prev_sibling : node -> node
CAMLprim value octs_node_prev_sibling(value v_node /* : node */) {
  CAMLparam1(v_node);
  TSNode node = *TSNode_val(v_node);
  CAMLreturn(alloc_node(ts_node_prev_sibling(node)));
}

/// val node_next_named_sibling : node -> node
CAMLprim value octs_node_next_named_sibling(value v_node /* : node */) {
  CAMLparam1(v_node);
  TSNode node = *TSNode_val(v_node);
  CAMLreturn(alloc_node(ts_node_next_named_sibling(node)));
}

/// val node_prev_named_sibling : node -> node
CAMLprim value octs_node_prev_named_sibling(value v_node /* : node */) {
  CAMLparam1(v_node);
  TSNode node = *TSNode_val(v_node);
  CAMLreturn(alloc_node(ts_node_prev_named_sibling(node)));
}

/// val node_first_child_for_byte : node -> int -> node
CAMLprim value octs_node_first_child_for_byte(value v_node /* : node */,
                                              value v_byte /* : int */) {
  CAMLparam2(v_node, v_byte);
  TSNode node = *TSNode_val(v_node);
  CAMLreturn(alloc_node(ts_node_first_child_for_byte(node, Int_val(v_byte))));
}

/// val node_first_named_child_for_byte : node -> int -> node
CAMLprim value octs_node_first_named_child_for_byte(value v_node /* : node */,
                                                    value v_byte /* : int */) {
  CAMLparam2(v_node, v_byte);
  TSNode node = *TSNode_val(v_node);
  CAMLreturn(
      alloc_node(ts_node_first_named_child_for_byte(node, Int_val(v_byte))));
}

/// val node_descendant_count : node -> int
CAMLprim value octs_node_descendant_count(value v_node /* : node */) {
  // safety: no allocation.
  return Val_int(ts_node_descendant_count(*TSNode_val(v_node)));
}

/// val node_descendant_for_byte_range : node -> int -> int -> node
CAMLprim value octs_node_descendant_for_byte_range(value v_node /* : node */,
                                                   value v_start /* : int */,
                                                   value v_end /* : int */) {
  CAMLparam3(v_node, v_start, v_end);
  TSNode node = *TSNode_val(v_node);
  CAMLreturn(alloc_node(ts_node_descendant_for_byte_range(
      node, Int_val(v_start), Int_val(v_end))));
}

/// val node_descendant_for_point_range : node -> point -> point -> node
CAMLprim value octs_node_descendant_for_point_range(value v_node /* : node */,
                                                    value v_start /* : point */,
                                                    value v_end /* : point */) {
  CAMLparam3(v_node, v_start, v_end);
  // safety: extract node and points before allocating the result.
  TSNode node = *TSNode_val(v_node);
  TSPoint start = point_val(v_start);
  TSPoint end = point_val(v_end);
  CAMLreturn(alloc_node(ts_node_descendant_for_point_range(node, start, end)));
}

/// val node_named_descendant_for_byte_range : node -> int -> int -> node
CAMLprim value octs_node_named_descendant_for_byte_range(
    value v_node /* : node */, value v_start /* : int */,
    value v_end /* : int */) {
  CAMLparam3(v_node, v_start, v_end);
  TSNode node = *TSNode_val(v_node);
  CAMLreturn(alloc_node(ts_node_named_descendant_for_byte_range(
      node, Int_val(v_start), Int_val(v_end))));
}

/// val node_named_descendant_for_point_range : node -> point -> point -> node
CAMLprim value octs_node_named_descendant_for_point_range(
    value v_node /* : node */, value v_start /* : point */,
    value v_end /* : point */) {
  CAMLparam3(v_node, v_start, v_end);
  TSNode node = *TSNode_val(v_node);
  TSPoint start = point_val(v_start);
  TSPoint end = point_val(v_end);
  CAMLreturn(
      alloc_node(ts_node_named_descendant_for_point_range(node, start, end)));
}

/// val node_eq : node -> node -> bool
CAMLprim value octs_node_eq(value v_a /* : node */, value v_b /* : node */) {
  // safety: no allocation.
  return Val_bool(ts_node_eq(*TSNode_val(v_a), *TSNode_val(v_b)));
}

// -- Custom index helpers (not part of the tree-sitter C API) ----------------

/// val node_index : node -> int
/// Compute the node's index among its parent's children by counting preceding
/// siblings.
CAMLprim value octs_node_index(value v_node /* : node */) {
  // safety: no allocation; all work is on stack-copied TSNode values.
  TSNode prev = ts_node_prev_sibling(*TSNode_val(v_node));
  uint32_t c = 0;
  while (!ts_node_is_null(prev)) {
    c++;
    prev = ts_node_prev_sibling(prev);
  }
  return Val_int(c);
}

/// val node_named_index : node -> int
/// Compute the node's index among its parent's *named* children.
CAMLprim value octs_node_named_index(value v_node /* : node */) {
  // safety: no allocation.
  TSNode prev = ts_node_prev_named_sibling(*TSNode_val(v_node));
  uint32_t c = 0;
  while (!ts_node_is_null(prev)) {
    c++;
    prev = ts_node_prev_named_sibling(prev);
  }
  return Val_int(c);
}

/// val node_bounded_named_index : node -> int
/// Like node_named_index but caps the count at 2.
CAMLprim value octs_node_bounded_named_index(value v_node /* : node */) {
  // safety: no allocation.
  TSNode prev = ts_node_prev_named_sibling(*TSNode_val(v_node));
  uint32_t c = 0;
  while (!ts_node_is_null(prev) && c < 2) {
    c++;
    prev = ts_node_prev_named_sibling(prev);
  }
  return Val_int(c);
}

// ============================================================================
// Tree cursor
// ============================================================================

/// val tree_cursor_new : node -> tree_cursor
CAMLprim value octs_tree_cursor_new(value v_node /* : node */) {
  CAMLparam1(v_node);
  CAMLlocal1(v);
  TSNode node = *TSNode_val(v_node);
  TSTreeCursor cursor = ts_tree_cursor_new(node);
  v = caml_alloc_custom(&tree_cursor_ops, sizeof cursor, 0, 1);
  memcpy(Data_custom_val(v), &cursor, sizeof cursor);
  CAMLreturn(v);
}

/// val tree_cursor_delete : tree_cursor -> unit
CAMLprim value octs_tree_cursor_delete(value v_cursor /* : tree_cursor */) {
  ts_tree_cursor_delete(TSTreeCursor_val(v_cursor));
  return Val_unit;
}

/// val tree_cursor_reset : tree_cursor -> node -> unit
CAMLprim value octs_tree_cursor_reset(value v_cursor /* : tree_cursor */,
                                      value v_node /* : node */) {
  // safety: no allocation. Cursor is mutated in-place inside the custom block.
  TSNode node = *TSNode_val(v_node);
  ts_tree_cursor_reset(TSTreeCursor_val(v_cursor), node);
  return Val_unit;
}

/// val tree_cursor_reset_to : tree_cursor -> tree_cursor -> unit
CAMLprim value octs_tree_cursor_reset_to(value v_dst /* : tree_cursor */,
                                         value v_src /* : tree_cursor */) {
  // safety: no allocation.
  ts_tree_cursor_reset_to(TSTreeCursor_val(v_dst), TSTreeCursor_val(v_src));
  return Val_unit;
}

/// val tree_cursor_current_node : tree_cursor -> node
CAMLprim value
octs_tree_cursor_current_node(value v_cursor /* : tree_cursor */) {
  CAMLparam1(v_cursor);
  TSNode node = ts_tree_cursor_current_node(TSTreeCursor_val(v_cursor));
  CAMLreturn(alloc_node(node));
}

/// val tree_cursor_current_field_name : tree_cursor -> string option
CAMLprim value
octs_tree_cursor_current_field_name(value v_cursor /* : tree_cursor */) {
  CAMLparam1(v_cursor);
  CAMLlocal1(v_str);
  const char *name =
      ts_tree_cursor_current_field_name(TSTreeCursor_val(v_cursor));
  if (!name) {
    CAMLreturn(Val_none);
  }
  v_str = caml_copy_string(name);
  CAMLreturn(val_some(v_str));
}

/// val tree_cursor_current_field_id : tree_cursor -> int
CAMLprim value
octs_tree_cursor_current_field_id(value v_cursor /* : tree_cursor */) {
  // safety: no allocation.
  return Val_int(ts_tree_cursor_current_field_id(TSTreeCursor_val(v_cursor)));
}

/// val tree_cursor_goto_parent : tree_cursor -> bool
CAMLprim value
octs_tree_cursor_goto_parent(value v_cursor /* : tree_cursor */) {
  // safety: no allocation. Cursor is mutated in-place.
  return Val_bool(ts_tree_cursor_goto_parent(TSTreeCursor_val(v_cursor)));
}

/// val tree_cursor_goto_next_sibling : tree_cursor -> bool
CAMLprim value
octs_tree_cursor_goto_next_sibling(value v_cursor /* : tree_cursor */) {
  // safety: no allocation.
  return Val_bool(ts_tree_cursor_goto_next_sibling(TSTreeCursor_val(v_cursor)));
}

/// val tree_cursor_goto_previous_sibling : tree_cursor -> bool
CAMLprim value
octs_tree_cursor_goto_previous_sibling(value v_cursor /* : tree_cursor */) {
  // safety: no allocation.
  return Val_bool(
      ts_tree_cursor_goto_previous_sibling(TSTreeCursor_val(v_cursor)));
}

/// val tree_cursor_goto_first_child : tree_cursor -> bool
CAMLprim value
octs_tree_cursor_goto_first_child(value v_cursor /* : tree_cursor */) {
  // safety: no allocation.
  return Val_bool(ts_tree_cursor_goto_first_child(TSTreeCursor_val(v_cursor)));
}

/// val tree_cursor_goto_last_child : tree_cursor -> bool
CAMLprim value
octs_tree_cursor_goto_last_child(value v_cursor /* : tree_cursor */) {
  // safety: no allocation.
  return Val_bool(ts_tree_cursor_goto_last_child(TSTreeCursor_val(v_cursor)));
}

/// val tree_cursor_goto_descendant : tree_cursor -> int -> unit
CAMLprim value octs_tree_cursor_goto_descendant(
    value v_cursor /* : tree_cursor */, value v_index /* : int */) {
  // safety: no allocation.
  ts_tree_cursor_goto_descendant(TSTreeCursor_val(v_cursor), Int_val(v_index));
  return Val_unit;
}

/// val tree_cursor_current_descendant_index : tree_cursor -> int
CAMLprim value
octs_tree_cursor_current_descendant_index(value v_cursor /* : tree_cursor */) {
  // safety: no allocation.
  return Val_int(
      ts_tree_cursor_current_descendant_index(TSTreeCursor_val(v_cursor)));
}

/// val tree_cursor_current_depth : tree_cursor -> int
CAMLprim value
octs_tree_cursor_current_depth(value v_cursor /* : tree_cursor */) {
  // safety: no allocation.
  return Val_int(ts_tree_cursor_current_depth(TSTreeCursor_val(v_cursor)));
}

/// val tree_cursor_goto_first_child_for_byte : tree_cursor -> int -> int
/// Returns the child index, or -1 if no child was found.
CAMLprim value octs_tree_cursor_goto_first_child_for_byte(
    value v_cursor /* : tree_cursor */, value v_byte /* : int */) {
  // safety: no allocation.
  int64_t idx = ts_tree_cursor_goto_first_child_for_byte(
      TSTreeCursor_val(v_cursor), Int_val(v_byte));
  return Val_int(idx);
}

/// val tree_cursor_goto_first_child_for_point : tree_cursor -> point -> int
/// Returns the child index, or -1 if no child was found.
CAMLprim value octs_tree_cursor_goto_first_child_for_point(
    value v_cursor /* : tree_cursor */, value v_point /* : point */) {
  // safety: no allocation. point_val does not allocate.
  TSPoint p = point_val(v_point);
  int64_t idx =
      ts_tree_cursor_goto_first_child_for_point(TSTreeCursor_val(v_cursor), p);
  return Val_int(idx);
}

/// val tree_cursor_copy : tree_cursor -> tree_cursor
CAMLprim value octs_tree_cursor_copy(value v_cursor /* : tree_cursor */) {
  CAMLparam1(v_cursor);
  CAMLlocal1(v);
  TSTreeCursor copy = ts_tree_cursor_copy(TSTreeCursor_val(v_cursor));
  v = caml_alloc_custom(&tree_cursor_ops, sizeof copy, 0, 1);
  memcpy(Data_custom_val(v), &copy, sizeof copy);
  CAMLreturn(v);
}

// ============================================================================
// Query
// ============================================================================

/// val query_new : language -> string -> query
/// @note Raises [Failure] if the query source has a syntax error, with a
///       message containing the error type and byte offset.
CAMLprim value octs_query_new(value v_lang /* : language */,
                              value v_source /* : string */) {
  CAMLparam2(v_lang, v_source);
  CAMLlocal1(v);

  const TSLanguage *lang = TSLanguage_val(v_lang);
  const char *source = String_val(v_source);
  uint32_t source_len = caml_string_length(v_source);

  uint32_t error_offset;
  TSQueryError error_type;
  TSQuery *query =
      ts_query_new(lang, source, source_len, &error_offset, &error_type);

  if (!query) {
    static const char *error_names[] = {
        "none",    "syntax",    "node_type", "field",
        "capture", "structure", "language",
    };
    const char *name = (error_type < 7) ? error_names[error_type] : "unknown";
    char msg[256];
    snprintf(msg, sizeof(msg), "query error: %s at byte offset %u", name,
             error_offset);
    caml_failwith(msg);
  }

  v = caml_alloc_custom(&query_ops, sizeof(TSQuery *), 0, 1);
  TSQuery_val(v) = query;
  CAMLreturn(v);
}

/// val query_delete : query -> unit
CAMLprim value octs_query_delete(value v_query /* : query */) {
  TSQuery *q = TSQuery_val(v_query);
  if (q) {
    ts_query_delete(q);
    TSQuery_val(v_query) = NULL;
  }
  return Val_unit;
}

/// val query_pattern_count : query -> int
CAMLprim value octs_query_pattern_count(value v_query /* : query */) {
  // safety: no allocation.
  return Val_int(ts_query_pattern_count(TSQuery_val(v_query)));
}

/// val query_capture_count : query -> int
CAMLprim value octs_query_capture_count(value v_query /* : query */) {
  // safety: no allocation.
  return Val_int(ts_query_capture_count(TSQuery_val(v_query)));
}

/// val query_string_count : query -> int
CAMLprim value octs_query_string_count(value v_query /* : query */) {
  // safety: no allocation.
  return Val_int(ts_query_string_count(TSQuery_val(v_query)));
}

/// val query_start_byte_for_pattern : query -> int -> int
CAMLprim value octs_query_start_byte_for_pattern(value v_query /* : query */,
                                                 value v_index /* : int */) {
  // safety: no allocation.
  return Val_int(
      ts_query_start_byte_for_pattern(TSQuery_val(v_query), Int_val(v_index)));
}

/// val query_predicates_for_pattern :
///   query -> int -> query_predicate_step array
///
/// query_predicate_step =
///   | Done
///   | Capture of int
///   | String_literal of int
CAMLprim value octs_query_predicates_for_pattern(value v_query /* : query */,
                                                 value v_index /* : int */) {
  CAMLparam2(v_query, v_index);
  CAMLlocal2(v_arr, v_step);

  uint32_t step_count;
  const TSQueryPredicateStep *steps = ts_query_predicates_for_pattern(
      TSQuery_val(v_query), Int_val(v_index), &step_count);

  v_arr = caml_alloc(step_count, 0);
  for (uint32_t i = 0; i < step_count; i++) {
    switch (steps[i].type) {
    case TSQueryPredicateStepTypeDone:
      // safety: Val_int(0) is an immediate; no allocation needed.
      Store_field(v_arr, i, Val_int(0));
      break;
    case TSQueryPredicateStepTypeCapture:
      v_step = caml_alloc(1, 0);
      Store_field(v_step, 0, Val_int(steps[i].value_id));
      Store_field(v_arr, i, v_step);
      break;
    case TSQueryPredicateStepTypeString:
      v_step = caml_alloc(1, 1);
      Store_field(v_step, 0, Val_int(steps[i].value_id));
      Store_field(v_arr, i, v_step);
      break;
    }
  }
  CAMLreturn(v_arr);
}

/// val query_is_pattern_rooted : query -> int -> bool
CAMLprim value octs_query_is_pattern_rooted(value v_query /* : query */,
                                            value v_index /* : int */) {
  // safety: no allocation.
  return Val_bool(
      ts_query_is_pattern_rooted(TSQuery_val(v_query), Int_val(v_index)));
}

/// val query_is_pattern_non_local : query -> int -> bool
CAMLprim value octs_query_is_pattern_non_local(value v_query /* : query */,
                                               value v_index /* : int */) {
  // safety: no allocation.
  return Val_bool(
      ts_query_is_pattern_non_local(TSQuery_val(v_query), Int_val(v_index)));
}

/// val query_is_pattern_guaranteed_at_step : query -> int -> bool
CAMLprim value octs_query_is_pattern_guaranteed_at_step(
    value v_query /* : query */, value v_offset /* : int */) {
  // safety: no allocation.
  return Val_bool(ts_query_is_pattern_guaranteed_at_step(TSQuery_val(v_query),
                                                         Int_val(v_offset)));
}

/// val query_capture_name_for_id : query -> int -> string
CAMLprim value octs_query_capture_name_for_id(value v_query /* : query */,
                                              value v_index /* : int */) {
  CAMLparam2(v_query, v_index);
  uint32_t length;
  const char *name = ts_query_capture_name_for_id(TSQuery_val(v_query),
                                                  Int_val(v_index), &length);
  CAMLreturn(caml_alloc_initialized_string(length, name));
}

/// val query_capture_quantifier_for_id : query -> int -> int -> int
CAMLprim value octs_query_capture_quantifier_for_id(
    value v_query /* : query */, value v_pattern /* : int */,
    value v_capture /* : int */) {
  // safety: no allocation.
  return Val_int(ts_query_capture_quantifier_for_id(
      TSQuery_val(v_query), Int_val(v_pattern), Int_val(v_capture)));
}

/// val query_string_value_for_id : query -> int -> string
CAMLprim value octs_query_string_value_for_id(value v_query /* : query */,
                                              value v_index /* : int */) {
  CAMLparam2(v_query, v_index);
  uint32_t length;
  const char *s = ts_query_string_value_for_id(TSQuery_val(v_query),
                                               Int_val(v_index), &length);
  CAMLreturn(caml_alloc_initialized_string(length, s));
}

/// val query_disable_capture : query -> string -> unit
CAMLprim value octs_query_disable_capture(value v_query /* : query */,
                                          value v_name /* : string */) {
  // safety: no allocation. String_val is stable since we don't allocate.
  ts_query_disable_capture(TSQuery_val(v_query), String_val(v_name),
                           caml_string_length(v_name));
  return Val_unit;
}

/// val query_disable_pattern : query -> int -> unit
CAMLprim value octs_query_disable_pattern(value v_query /* : query */,
                                          value v_index /* : int */) {
  // safety: no allocation.
  ts_query_disable_pattern(TSQuery_val(v_query), Int_val(v_index));
  return Val_unit;
}

// ============================================================================
// Query cursor
// ============================================================================

/// val query_cursor_new : unit -> query_cursor
CAMLprim value octs_query_cursor_new(value v_unit /* : unit */) {
  CAMLparam1(v_unit);
  CAMLlocal1(v);
  TSQueryCursor *cursor = ts_query_cursor_new();
  v = caml_alloc_custom(&query_cursor_ops, sizeof(TSQueryCursor *), 0, 1);
  TSQueryCursor_val(v) = cursor;
  CAMLreturn(v);
}

/// val query_cursor_delete : query_cursor -> unit
CAMLprim value octs_query_cursor_delete(value v_cursor /* : query_cursor */) {
  TSQueryCursor *c = TSQueryCursor_val(v_cursor);
  if (c) {
    ts_query_cursor_delete(c);
    TSQueryCursor_val(v_cursor) = NULL;
  }
  return Val_unit;
}

/// val query_cursor_exec : query_cursor -> query -> node -> unit
CAMLprim value octs_query_cursor_exec(value v_cursor /* : query_cursor */,
                                      value v_query /* : query */,
                                      value v_node /* : node */) {
  // safety: no allocation. Node is copied by value.
  TSNode node = *TSNode_val(v_node);
  ts_query_cursor_exec(TSQueryCursor_val(v_cursor), TSQuery_val(v_query), node);
  return Val_unit;
}

/// val query_cursor_did_exceed_match_limit : query_cursor -> bool
CAMLprim value
octs_query_cursor_did_exceed_match_limit(value v_cursor /* : query_cursor */) {
  // safety: no allocation.
  return Val_bool(
      ts_query_cursor_did_exceed_match_limit(TSQueryCursor_val(v_cursor)));
}

/// val query_cursor_match_limit : query_cursor -> int
CAMLprim value
octs_query_cursor_match_limit(value v_cursor /* : query_cursor */) {
  // safety: no allocation.
  return Val_int(ts_query_cursor_match_limit(TSQueryCursor_val(v_cursor)));
}

/// val query_cursor_set_match_limit : query_cursor -> int -> unit
CAMLprim value octs_query_cursor_set_match_limit(
    value v_cursor /* : query_cursor */, value v_limit /* : int */) {
  // safety: no allocation.
  ts_query_cursor_set_match_limit(TSQueryCursor_val(v_cursor),
                                  Int_val(v_limit));
  return Val_unit;
}

/// val query_cursor_set_byte_range : query_cursor -> int -> int -> unit
CAMLprim value octs_query_cursor_set_byte_range(
    value v_cursor /* : query_cursor */, value v_start /* : int */,
    value v_end /* : int */) {
  // safety: no allocation.
  ts_query_cursor_set_byte_range(TSQueryCursor_val(v_cursor), Int_val(v_start),
                                 Int_val(v_end));
  return Val_unit;
}

/// val query_cursor_set_point_range : query_cursor -> point -> point -> unit
CAMLprim value octs_query_cursor_set_point_range(
    value v_cursor /* : query_cursor */, value v_start /* : point */,
    value v_end /* : point */) {
  // safety: no allocation. point_val does not allocate.
  ts_query_cursor_set_point_range(TSQueryCursor_val(v_cursor),
                                  point_val(v_start), point_val(v_end));
  return Val_unit;
}

/// Build an OCaml query_match record from a TSQueryMatch.
///
/// query_capture = { capture_node : node; capture_index : int }
/// query_match = { match_id : int; pattern_index : int;
///                 captures : query_capture array }
///
/// May trigger GC. Caller must be in a CAMLparam context.
static value val_of_query_match(const TSQueryMatch *match) {
  CAMLparam0();
  CAMLlocal4(v_match, v_captures, v_capture, v_node);

  v_captures = caml_alloc(match->capture_count, 0);
  for (uint16_t i = 0; i < match->capture_count; i++) {
    // safety: match->captures points to cursor-owned C-heap memory, not
    // OCaml heap, so it is stable across GC cycles.
    v_node = alloc_node(match->captures[i].node);
    v_capture = caml_alloc(2, 0);
    Store_field(v_capture, 0, v_node);
    Store_field(v_capture, 1, Val_int(match->captures[i].index));
    Store_field(v_captures, i, v_capture);
  }

  v_match = caml_alloc(3, 0);
  Store_field(v_match, 0, Val_int(match->id));
  Store_field(v_match, 1, Val_int(match->pattern_index));
  Store_field(v_match, 2, v_captures);
  CAMLreturn(v_match);
}

/// val query_cursor_next_match : query_cursor -> query_match option
CAMLprim value
octs_query_cursor_next_match(value v_cursor /* : query_cursor */) {
  CAMLparam1(v_cursor);
  CAMLlocal1(v_match);

  TSQueryMatch match;
  if (!ts_query_cursor_next_match(TSQueryCursor_val(v_cursor), &match)) {
    CAMLreturn(Val_none);
  }

  v_match = val_of_query_match(&match);
  CAMLreturn(val_some(v_match));
}

/// val query_cursor_next_capture :
///   query_cursor -> (query_match * int) option
CAMLprim value
octs_query_cursor_next_capture(value v_cursor /* : query_cursor */) {
  CAMLparam1(v_cursor);
  CAMLlocal2(v_match, v_pair);

  TSQueryMatch match;
  uint32_t capture_index;
  if (!ts_query_cursor_next_capture(TSQueryCursor_val(v_cursor), &match,
                                    &capture_index)) {
    CAMLreturn(Val_none);
  }

  v_match = val_of_query_match(&match);
  v_pair = caml_alloc(2, 0);
  Store_field(v_pair, 0, v_match);
  Store_field(v_pair, 1, Val_int(capture_index));
  CAMLreturn(val_some(v_pair));
}

/// val query_cursor_remove_match : query_cursor -> int -> unit
CAMLprim value octs_query_cursor_remove_match(
    value v_cursor /* : query_cursor */, value v_id /* : int */) {
  // safety: no allocation.
  ts_query_cursor_remove_match(TSQueryCursor_val(v_cursor), Int_val(v_id));
  return Val_unit;
}

/// val query_cursor_set_max_start_depth : query_cursor -> int -> unit
CAMLprim value octs_query_cursor_set_max_start_depth(
    value v_cursor /* : query_cursor */, value v_depth /* : int */) {
  // safety: no allocation.
  ts_query_cursor_set_max_start_depth(TSQueryCursor_val(v_cursor),
                                      Int_val(v_depth));
  return Val_unit;
}

// ============================================================================
// Language
// ============================================================================

/// val language_copy : language -> language
CAMLprim value octs_language_copy(value v_lang /* : language */) {
  CAMLparam1(v_lang);
  CAMLreturn(alloc_language(TSLanguage_val(v_lang)));
}

/// val language_delete : language -> unit
CAMLprim value octs_language_delete(value v_lang /* : language */) {
  const TSLanguage *lang = TSLanguage_val(v_lang);
  if (lang) {
    ts_language_delete(lang);
    TSLanguage_val(v_lang) = NULL;
  }
  return Val_unit;
}

/// val language_symbol_count : language -> int
CAMLprim value octs_language_symbol_count(value v_lang /* : language */) {
  // safety: no allocation.
  return Val_int(ts_language_symbol_count(TSLanguage_val(v_lang)));
}

/// val language_state_count : language -> int
CAMLprim value octs_language_state_count(value v_lang /* : language */) {
  // safety: no allocation.
  return Val_int(ts_language_state_count(TSLanguage_val(v_lang)));
}

/// val language_symbol_name : language -> int -> string
CAMLprim value octs_language_symbol_name(value v_lang /* : language */,
                                         value v_symbol /* : int */) {
  CAMLparam2(v_lang, v_symbol);
  const char *name =
      ts_language_symbol_name(TSLanguage_val(v_lang), Int_val(v_symbol));
  CAMLreturn(caml_copy_string(name ? name : ""));
}

/// val language_symbol_for_name : language -> string -> bool -> int
CAMLprim value octs_language_symbol_for_name(value v_lang /* : language */,
                                             value v_name /* : string */,
                                             value v_named /* : bool */) {
  // safety: no allocation. String_val is stable.
  return Val_int(ts_language_symbol_for_name(
      TSLanguage_val(v_lang), String_val(v_name), caml_string_length(v_name),
      Bool_val(v_named)));
}

/// val language_field_count : language -> int
CAMLprim value octs_language_field_count(value v_lang /* : language */) {
  // safety: no allocation.
  return Val_int(ts_language_field_count(TSLanguage_val(v_lang)));
}

/// val language_field_name_for_id : language -> int -> string option
CAMLprim value octs_language_field_name_for_id(value v_lang /* : language */,
                                               value v_id /* : int */) {
  CAMLparam2(v_lang, v_id);
  CAMLlocal1(v_str);
  const char *name =
      ts_language_field_name_for_id(TSLanguage_val(v_lang), Int_val(v_id));
  if (!name) {
    CAMLreturn(Val_none);
  }
  v_str = caml_copy_string(name);
  CAMLreturn(val_some(v_str));
}

/// val language_field_id_for_name : language -> string -> int
CAMLprim value octs_language_field_id_for_name(value v_lang /* : language */,
                                               value v_name /* : string */) {
  // safety: no allocation.
  return Val_int(ts_language_field_id_for_name(
      TSLanguage_val(v_lang), String_val(v_name), caml_string_length(v_name)));
}

/// val language_symbol_type : language -> int -> int
/// Returns 0 for regular, 1 for anonymous, 2 for auxiliary.
CAMLprim value octs_language_symbol_type(value v_lang /* : language */,
                                         value v_symbol /* : int */) {
  // safety: no allocation.
  return Val_int(
      ts_language_symbol_type(TSLanguage_val(v_lang), Int_val(v_symbol)));
}

/// val language_version : language -> int
CAMLprim value octs_language_version(value v_lang /* : language */) {
  // safety: no allocation.
  return Val_int(ts_language_version(TSLanguage_val(v_lang)));
}

/// val language_next_state : language -> int -> int -> int
CAMLprim value octs_language_next_state(value v_lang /* : language */,
                                        value v_state /* : int */,
                                        value v_symbol /* : int */) {
  // safety: no allocation.
  return Val_int(ts_language_next_state(TSLanguage_val(v_lang),
                                        Int_val(v_state), Int_val(v_symbol)));
}

// ============================================================================
// Lookahead iterator
// ============================================================================

/// val lookahead_iterator_new : language -> int -> lookahead_iterator option
CAMLprim value octs_lookahead_iterator_new(value v_lang /* : language */,
                                           value v_state /* : int */) {
  CAMLparam2(v_lang, v_state);
  CAMLlocal1(v);

  TSLookaheadIterator *it =
      ts_lookahead_iterator_new(TSLanguage_val(v_lang), Int_val(v_state));
  if (!it) {
    CAMLreturn(Val_none);
  }

  v = caml_alloc_custom(&lookahead_iterator_ops, sizeof(TSLookaheadIterator *),
                        0, 1);
  TSLookaheadIterator_val(v) = it;
  CAMLreturn(val_some(v));
}

/// val lookahead_iterator_delete : lookahead_iterator -> unit
CAMLprim value
octs_lookahead_iterator_delete(value v_iter /* : lookahead_iterator */) {
  TSLookaheadIterator *it = TSLookaheadIterator_val(v_iter);
  if (it) {
    ts_lookahead_iterator_delete(it);
    TSLookaheadIterator_val(v_iter) = NULL;
  }
  return Val_unit;
}

/// val lookahead_iterator_reset_state : lookahead_iterator -> int -> bool
CAMLprim value octs_lookahead_iterator_reset_state(
    value v_iter /* : lookahead_iterator */, value v_state /* : int */) {
  // safety: no allocation.
  return Val_bool(ts_lookahead_iterator_reset_state(
      TSLookaheadIterator_val(v_iter), Int_val(v_state)));
}

/// val lookahead_iterator_reset :
///   lookahead_iterator -> language -> int -> bool
CAMLprim value octs_lookahead_iterator_reset(
    value v_iter /* : lookahead_iterator */, value v_lang /* : language */,
    value v_state /* : int */) {
  // safety: no allocation.
  return Val_bool(ts_lookahead_iterator_reset(TSLookaheadIterator_val(v_iter),
                                              TSLanguage_val(v_lang),
                                              Int_val(v_state)));
}

/// val lookahead_iterator_language : lookahead_iterator -> language
CAMLprim value
octs_lookahead_iterator_language(value v_iter /* : lookahead_iterator */) {
  CAMLparam1(v_iter);
  const TSLanguage *lang =
      ts_lookahead_iterator_language(TSLookaheadIterator_val(v_iter));
  CAMLreturn(alloc_language(lang));
}

/// val lookahead_iterator_next : lookahead_iterator -> bool
CAMLprim value
octs_lookahead_iterator_next(value v_iter /* : lookahead_iterator */) {
  // safety: no allocation.
  return Val_bool(ts_lookahead_iterator_next(TSLookaheadIterator_val(v_iter)));
}

/// val lookahead_iterator_current_symbol : lookahead_iterator -> int
CAMLprim value octs_lookahead_iterator_current_symbol(
    value v_iter /* : lookahead_iterator */) {
  // safety: no allocation.
  return Val_int(
      ts_lookahead_iterator_current_symbol(TSLookaheadIterator_val(v_iter)));
}

/// val lookahead_iterator_current_symbol_name :
///   lookahead_iterator -> string
CAMLprim value octs_lookahead_iterator_current_symbol_name(
    value v_iter /* : lookahead_iterator */) {
  CAMLparam1(v_iter);
  const char *name = ts_lookahead_iterator_current_symbol_name(
      TSLookaheadIterator_val(v_iter));
  CAMLreturn(caml_copy_string(name));
}
