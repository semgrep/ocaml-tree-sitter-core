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

def _install_dependency(name: str, dir_path: str) -> None:
  print_warning(f"Checking {name} installation")
  if not os.path.exists(os.path.join(dir_path, f"node_modules/{name}")):
    print_warning(f"No {name} package found. Attempting `npm i {name}` in {dir_path}")
    exit_installation = wrap_call(["npm", "i", name], cwd=dir_path)
    if exit_installation != 0:
      print_warning(f"Could not install tree-sitter. Try manually with `npm i {name}` inside {dir_path}")
      sys.exit(exit_installation)

def _check_and_install_tree_sitter(dir_path)-> None:
  """
    Checks tree-sitter-installation inside dir_path.
    Ensures that tree-sitter and tree-sitter-cli are installed locally in node_modules
  """
  deps = ["nan", "tree-sitter", "tree-sitter-cli"]
  for d in deps:
    _install_dependency(d, dir_path)

def _check_node_installation()-> None:
  """
    Checks node installation by invoking `node --version`
  """
  print_warning(f"Checking node installation")
  exit_code = wrap_call(["node", "--version"])
  if exit_code != 0:
    print_warning(f"Please install NodeJS with `brew install node`")
    sys.exit(exit_code)

def _generate_json(grammar_dir: str) -> Optional[str]:
  """
    Generates grammar.json from grammar.js files of tree-sitter
  """
  print_warning(f"Generating grammar.json from {grammar_dir}")

  # Sanity check with -V
  subprocess.call([LOCAL_TREE_SITTER_PATH, "-V"], cwd=grammar_dir)

  exit_code = subprocess.call([LOCAL_TREE_SITTER_PATH, "generate"], cwd=grammar_dir)
  if exit_code != 0:
    print("Could not generate grammar.json. Try running `tree-sitter generate` manually!")
    sys.exit(1)
  return os.path.join(grammar_dir, "grammar.json")

def parse_grammar(grammar_path: str) -> Optional[Dict[str, Any]]:
  """
    Parses grammar.json in tree-sitter definitions. Generates
    this file if necessary from grammar.js
  """
  _check_and_install_tree_sitter(grammar_path)
  json_file = _generate_json(grammar_path)
  with open(json_file, 'r') as generate_j:
    try:
      grammar = json.load(generate_j)
    except JSONDecodeError as _:
      print_warning(f"Invalid grammar.json file specified.")
  if not grammar:
    print_warning(f"Could not find grammar.json")
    sys.exit(1)
  return grammar

def generate_cst_json_dumper(language_name, dir_path):
  print_warning(f"Generating bindings for language '{language_name}' in {dir_path}")
  template = f"""#!/usr/bin/env node

const Parser = require('tree-sitter');
const {language_name.capitalize()} = require('.');

var args = process.argv.slice(2);

var fs = require("fs");
const sourceCode = fs.readFileSync(args[0]).toString();

const parser = new Parser();
parser.setLanguage({language_name.capitalize()});
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

  wrap_call(["npm", "init", "-y"], cwd=dir_path)

  # hack to make sure the main entrypoint is index.js
  package_json = {}
  with open(os.path.join(dir_path, "package.json"), "r") as f:
    package_json = json.load(f)
    package_json["main"] = "index.js"
  with open(os.path.join(dir_path, "package.json"), "w") as f:
    json.dump(package_json, f)

  wrap_call(["npm", "install"], cwd=dir_path)
  exit_code = wrap_call(["npm", "link"], cwd=dir_path)
  if exit_code != 0:
    print_warning(f"Could not install language at {dir_path}. See README.md for instructions")
    sys.exit(1)



def dump_cst(fname:str, dir_path: str, input_file: str) -> None:
  print(f"Writing CST for {input_file}")
  if dir_path in input_file:
    input_file = os.path.relpath(input_file, dir_path)
  exit_code = subprocess.call(["node", fname, input_file], cwd=dir_path)

def dump_cst_native(fname:str, dir_path: str, input_file: str) -> None:
  print(f"Writing CST for {input_file}")
  if dir_path in input_file:
    input_file = os.path.relpath(input_file, dir_path)
  exit_code = subprocess.call([LOCAL_TREE_SITTER_PATH, "parse", input_file], cwd=dir_path)

def main(grammar_dir: str, input_file: str, is_native: bool)-> None:
  """
    Runs the given grammer to generate CST in s-expr or JSON format for a given file.
    It installs necessary prerequisites through npm locally on the path
  """
  _check_node_installation()
  install_specified_language(grammar_dir)
  grammar = parse_grammar(grammar_dir)
  language_name = grammar.get("name")
  fname = generate_cst_json_dumper(language_name, grammar_dir)
  if is_native:
    dump_cst_native(fname, grammar_dir, input_file)
  else:
    dump_cst(fname, grammar_dir, input_file)

if __name__ == "__main__":
  parser = argparse.ArgumentParser(description='Process some integers.')
  parser.add_argument('grammar_dir', type=str,
                    help='Directory containing grammar.js definition')
  parser.add_argument('--native', '-n', help='Print CST in native CST format (s-expr) of tree-sitter', action='store_true')
  parser.add_argument("input_file")
  args = parser.parse_args()
  main(args.grammar_dir, args.input_file, args.native)