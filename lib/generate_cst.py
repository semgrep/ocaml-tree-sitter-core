#!/usr/bin/env python3
import argparse
import json
import os
import subprocess
import sys
from typing import Any, Dict, List, Optional
from json import JSONDecodeError

LOCAL_TREE_SITTER_PATH = f"./node_modules/.bin/tree-sitter"

def wrap_call(cmd: List[str], **kwargs)->None:
  return subprocess.call(cmd, **{"stdout": subprocess.DEVNULL, "stderr": subprocess.DEVNULL, **kwargs})

def print_warning(msg):
  print(msg, file=sys.stderr)

def _check_and_install_tree_sitter(dir_path)-> None:
  """
    Checks tree-sitter-installation inside dir_path.
    Ensures that tree-sitter and tree-sitter-cli are installed locally in node_modules
  """
  print_warning(f"Checking tree-sitter installation")
  if not os.path.exists(os.path.join(dir_path, "node_modules/tree-sitter-cli")):
    print_warning(f"No tree-sitter package found. Attempting `npm i tree-sitter` in {dir_path}")
    exit_installation = subprocess.call(["npm", "i", "tree-sitter"], cwd=dir_path)
    if exit_installation != 0:
      print_warning(f"Could not install tree-sitter. Try manually with `npm i tree-sitter` inside {dir_path}")
      sys.exit(exit_installation)
  print_warning(f"Checking tree-sitter-cli installation")
  if not os.path.exists(os.path.join(dir_path, "node_modules/tree-sitter-cli")):
    print_warning(f"No tree-sitter-cli package found. Attempting `npm i tree-sitter-cli` in {dir_path}")
    exit_installation = subprocess.call(["npm", "i", "tree-sitter-cli"], cwd=dir_path)
    if exit_installation != 0:
      print_warning(f"Could not install tree-sitter-cli. Try manually with `npm i tree-sitter-cli` inside {dir_path}")
      sys.exit(exit_installation)

def _check_node_installation()-> None:
  """
    Checks node installation by invoking `node --version`
  """
  print_warning(f"Checking node installation")
  exit_code = wrap_call(["node", "--version"])
  if exit_code != 0:
    print_warning(f"Please install NodeJS with `brew install node`")
    sys.exit(exit_code)

def _generate_json(grammar_file: str) -> Optional[str]:
  """
    Generates grammar.json from grammar.js files of tree-sitter
  """
  if not grammar_file.endswith(".js"):
    print_warning(f"Does not understand {grammar_file}. Giving up")
    sys.exit(1)

  print_warning(f"Generating grammar.json from {grammar_file}")
  dir_path = os.path.dirname(grammar_file)
  exit_code = wrap_call([LOCAL_TREE_SITTER_PATH, "generate"], cwd=dir_path)
  if exit_code != 0:
    print("Could not generate grammar.json. Try running `tree-sitter generate` manually!")
    sys.exit(1)
  return os.path.join(dir_path, "grammar.json")

def parse_grammar(grammar_file: str, dir_path: str) -> Optional[Dict[str, Any]]:
  """
    Parses grammar.json in tree-sitter definitions. Generates
    this file if necessary from grammar.js
  """
  with open(grammar_file, 'r') as f:
    try:
      grammar = json.load(f)
    except JSONDecodeError as _:
      print_warning(f"Invalid grammar.json file specified. Generating ...")
      _check_and_install_tree_sitter(dir_path)
      json_file = _generate_json(grammar_file)
      if json_file:
        with open(json_file, 'r') as generate_j:
          grammar = json.load(generate_j)
  if not grammar:
    print_warning(f"Could not find grammar.json")
    sys.exit(1)
  return grammar

def generate_cst_json_dumper(language_name, dir_path):
  print_warning(f"Generating bindings for language '{language_name}' in {dir_path}")
  template = f"""#!/usr/bin/env node

const Parser = require('tree-sitter');
const {language_name} = require('.');

var args = process.argv.slice(2);

var fs = require("fs");
const sourceCode = fs.readFileSync(args[0]).toString();

const parser = new Parser();
parser.setLanguage({language_name});
const tree = parser.parse(sourceCode);

console.log(JSON.stringify(tree.rootNode, ["type", "children"], 2))
"""
  fname = f"{language_name}_cst_json_dump.js"
  fpath = os.path.join(dir_path, fname)
  if not os.path.exists(fpath):
    with open(fpath, 'w') as file:
      file.write(template)
  print_warning(f"Wrote {fpath}")
  return fname

def install_specified_language(dir_path: str) -> None:
  """
    Init, install, and link given npm package inside dir_path
  """
  print_warning("Installing and linking given language package locally.")
  # hack so that main entry point is always index.js
  wrap_call(["touch", "index.js"], cwd=dir_path)

  wrap_call(["npm", "init", "-y"], cwd=dir_path)
  wrap_call(["npm", "install"], cwd=dir_path)
  exit_code =wrap_call(["npm", "link"], cwd=dir_path)
  if exit_code != 0:
    print_warning(f"Could not install language at {dir_path}. See README.md for instructions")
    sys.exit(1)

def dump_cst(fname:str, dir_path: str, input_file: str) -> None:
  print(f"Writing CST for {input_file}")
  if dir_path in input_file:
    input_file = os.path.relpath(input_file, dir_path)
  exit_code = subprocess.call(["node", fname, input_file], cwd=dir_path)

def main(grammar_file: str, input_file: str)-> None:
  # install/check given grammar
  # run the generatad file
  _check_node_installation()
  dir_path = os.path.dirname(grammar_file)
  install_specified_language(dir_path)
  grammar = parse_grammar(grammar_file, dir_path)
  language_name = grammar.get("name")
  fname = generate_cst_json_dumper(language_name, dir_path)
  dump_cst(fname, dir_path, input_file)

if __name__ == "__main__":
  parser = argparse.ArgumentParser(description='Process some integers.')
  parser.add_argument('grammar_file', type=str,
                    help='grammar.json for which to generate the CST for')
  parser.add_argument("input_file")
  args = parser.parse_args()
  main(args.grammar_file, args.input_file)