#!/usr/bin/env node

const Parser = require('tree-sitter');
const pl = require('.');

var args = process.argv.slice(2);

var fs = require("fs");
const sourceCode = fs.readFileSync(args[0]).toString();

const parser = new Parser();
parser.setLanguage(pl);
const tree = parser.parse(sourceCode);
// TODO: add the position elements to AST
// console.log(JSON.stringify(tree.rootNode, ["type", "startPosition", "endPosition", "row", "column", "children"]))
console.log(JSON.stringify(tree.rootNode, ["type", "children"], 2))