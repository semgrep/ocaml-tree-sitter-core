#!/usr/bin/env node
/*
  Parse a source file with a tree-sitter-generated parser and dump
  the concrete syntax tree (CST) in json.

  Warning: This file is meant to be copied into the current folder.
  A direct call or a symbolic link won't work due to "require('.')".

  Requires:
  - tree-sitter, tree-sitter-cli.
  - the products of running 'tree-sitter generate' in the current folder.
*/

const Parser = require('tree-sitter');
const pl = require('tree-sitter-ruby');

var args = process.argv.slice(2);

var fs = require("fs");
const sourceCode = fs.readFileSync(args[0]).toString();

const parser = new Parser();
parser.setLanguage(pl);
const tree = parser.parse(sourceCode);

/*
   We have to select the fields we want otherwise they don't show.
   Specifying a list of fields is normally for filtering, but we have to do
   this because javascript.
*/
console.log(JSON.stringify(tree.rootNode, [
  "type",
  "startPosition",
  "endPosition",
  "row",
  "column",
  "children"
]))
