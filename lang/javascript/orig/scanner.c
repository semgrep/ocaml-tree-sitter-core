/*
  Copied from https://github.com/tree-sitter/tree-sitter-javascript

The MIT License (MIT)

Copyright (c) 2014 Max Brunsfeld

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

#include <tree_sitter/parser.h>
#include <wctype.h>

enum TokenType {
  AUTOMATIC_SEMICOLON,
  TEMPLATE_CHARS
};

void *tree_sitter_javascript_external_scanner_create() { return NULL; }
void tree_sitter_javascript_external_scanner_destroy(void *p) {}
void tree_sitter_javascript_external_scanner_reset(void *p) {}
unsigned tree_sitter_javascript_external_scanner_serialize(void *p, char *buffer) { return 0; }
void tree_sitter_javascript_external_scanner_deserialize(void *p, const char *b, unsigned n) {}

static void advance(TSLexer *lexer) { lexer->advance(lexer, false); }

static bool scan_whitespace_and_comments(TSLexer *lexer) {
  for (;;) {
    while (iswspace(lexer->lookahead)) {
      advance(lexer);
    }

    if (lexer->lookahead == '/') {
      advance(lexer);

      if (lexer->lookahead == '/') {
        advance(lexer);
        while (lexer->lookahead != 0 && lexer->lookahead != '\n') {
          advance(lexer);
        }
      } else if (lexer->lookahead == '*') {
        advance(lexer);
        while (lexer->lookahead != 0) {
          if (lexer->lookahead == '*') {
            advance(lexer);
            if (lexer->lookahead == '/') {
              advance(lexer);
              break;
            }
          } else {
            advance(lexer);
          }
        }
      } else {
        return false;
      }
    } else {
      return true;
    }
  }
}

bool tree_sitter_javascript_external_scanner_scan(void *payload, TSLexer *lexer,
                                                  const bool *valid_symbols) {
  if (valid_symbols[TEMPLATE_CHARS]) {
    if (valid_symbols[AUTOMATIC_SEMICOLON]) return false;
    lexer->result_symbol = TEMPLATE_CHARS;
    for (bool has_content = false;; has_content = true) {
      lexer->mark_end(lexer);
      switch (lexer->lookahead) {
        case '`':
          return has_content;
        case '\0':
          return false;
        case '$':
          advance(lexer);
          if (lexer->lookahead == '{') return has_content;
          break;
        case '\\':
          return has_content;
        default:
          advance(lexer);
      }
    }
  } else {
    lexer->result_symbol = AUTOMATIC_SEMICOLON;
    lexer->mark_end(lexer);

    for (;;) {
      if (lexer->lookahead == 0) return true;
      if (lexer->lookahead == '}') return true;
      if (lexer->is_at_included_range_start(lexer)) return true;
      if (!iswspace(lexer->lookahead)) return false;
      if (lexer->lookahead == '\n') break;
      advance(lexer);
    }

    advance(lexer);

    if (!scan_whitespace_and_comments(lexer)) return false;

    switch (lexer->lookahead) {
      case ',':
      case '.':
      case ':':
      case ';':
      case '*':
      case '%':
      case '>':
      case '<':
      case '=':
      case '[':
      case '(':
      case '?':
      case '^':
      case '|':
      case '&':
      case '/':
        return false;

      // Insert a semicolon before `--` and `++`, but not before binary `+` or `-`.
      case '+':
        advance(lexer);
        return lexer->lookahead == '+';
      case '-':
        advance(lexer);
        return lexer->lookahead == '-';

      // Don't insert a semicolon before `!=`, but do insert one before a unary `!`.
      case '!':
        advance(lexer);
        return lexer->lookahead != '=';

      // Don't insert a semicolon before `in` or `instanceof`, but do insert one
      // before an identifier.
      case 'i':
        advance(lexer);

        if (lexer->lookahead != 'n') return true;
        advance(lexer);

        if (!iswalpha(lexer->lookahead)) return false;

        for (unsigned i = 0; i < 8; i++) {
          if (lexer->lookahead != "stanceof"[i]) return true;
          advance(lexer);
        }

        if (!iswalpha(lexer->lookahead)) return false;
        break;
    }

    return true;
  }
}
