/*
   C stubs for the Null_tree test module.

   Exposes operations not reachable from the normal OCaml API,
   allowing the test to exercise the NULL-return code path in
   octs_parser_parse_string.
*/

#include <string.h>
#include "test_helpers.h"

/*
   Create a TSParser with no language set, wrapped as an OCaml custom
   block identical to what the generated octs_create_parser_<lang>
   produces.

   This simulates the state reached when ts_parser_set_language()
   returns false (ABI version mismatch) and the return value is
   not checked -- which is exactly what the generated code does.
*/

static void finalize_test_parser(value v) {
  parser_W *p = (parser_W *)Data_custom_val(v);
  if (p->parser)
    ts_parser_delete(p->parser);
}

static struct custom_operations test_parser_ops = {
  .identifier = "test parser",
  .finalize = finalize_test_parser,
  .compare = custom_compare_default,
  .hash = custom_hash_default,
  .serialize = custom_serialize_default,
  .deserialize = custom_deserialize_default,
};

CAMLprim value octs_test_create_parser_no_language(value unit) {
  CAMLparam1(unit);
  CAMLlocal1(v);

  parser_W pw;
  pw.parser = ts_parser_new();
  /* Intentionally do NOT call ts_parser_set_language(). */

  v = caml_alloc_custom(&test_parser_ops, sizeof(parser_W), 0, 1);
  memcpy(Data_custom_val(v), &pw, sizeof(parser_W));
  CAMLreturn(v);
}
