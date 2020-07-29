/*
  Copied from https://github.com/tree-sitter/tree-sitter-cpp

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
#include <string>
#include <cwctype>

namespace {

using std::wstring;
using std::iswspace;

enum TokenType {
  RAW_STRING_LITERAL,
};

struct Scanner {
  bool scan(TSLexer *lexer, const bool *valid_symbols) {
    while (iswspace(lexer->lookahead)) {
      lexer->advance(lexer, true);
    }

    lexer->result_symbol = RAW_STRING_LITERAL;

    // Raw string literals can start with: R, LR, uR, UR, u8R
    // Consume 'R'
    if (lexer->lookahead == 'L' || lexer->lookahead == 'U') {
      lexer->advance(lexer, false);
      if (lexer->lookahead != 'R') {
        return false;
      }
    } else if (lexer->lookahead == 'u') {
      lexer->advance(lexer, false);
      if (lexer->lookahead == '8') {
        lexer->advance(lexer, false);
        if (lexer->lookahead != 'R') {
          return false;
        }
      } else if (lexer->lookahead != 'R') {
        return false;
      }
    } else if (lexer->lookahead != 'R') {
      return false;
    }
    lexer->advance(lexer, false);

    // Consume '"'
    if (lexer->lookahead != '"') return false;
    lexer->advance(lexer, false);

    // Consume '(', delimiter
    wstring delimiter;
    for (;;) {
      if (lexer->lookahead == 0 || lexer->lookahead == '\\' || iswspace(lexer->lookahead)) {
        return false;
      }
      if (lexer->lookahead == '(') {
        lexer->advance(lexer, false);
        break;
      }
      delimiter += lexer->lookahead;
      lexer->advance(lexer, false);
    }

    // Consume content, delimiter, ')', '"'
    int delimiter_index = -1;
    for (;;) {
      if (lexer->lookahead == 0) return false;

      if (delimiter_index >= 0) {
        if (static_cast<unsigned>(delimiter_index) == delimiter.size()) {
          if (lexer->lookahead == '"') {
            lexer->advance(lexer, false);
            return true;
          } else {
            delimiter_index = -1;
          }
        } else {
          if (lexer->lookahead == delimiter[delimiter_index]) {
            delimiter_index++;
          } else {
            delimiter_index = -1;
          }
        }
      }

      if (delimiter_index == -1 && lexer->lookahead == ')') {
        delimiter_index = 0;
      }

      lexer->advance(lexer, false);
    }
  }
};

}

extern "C" {

void *tree_sitter_cpp_external_scanner_create() {
  return new Scanner();
}

bool tree_sitter_cpp_external_scanner_scan(void *payload, TSLexer *lexer,
                                            const bool *valid_symbols) {
  Scanner *scanner = static_cast<Scanner *>(payload);
  return scanner->scan(lexer, valid_symbols);
}

unsigned tree_sitter_cpp_external_scanner_serialize(void *payload, char *buffer) {
  return 0;
}

void tree_sitter_cpp_external_scanner_deserialize(void *payload, const char *buffer, unsigned length) {
}

void tree_sitter_cpp_external_scanner_destroy(void *payload) {
  Scanner *scanner = static_cast<Scanner *>(payload);
  delete scanner;
}

}
