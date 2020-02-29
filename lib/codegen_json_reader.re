open Common;
module B = Ast_grammar_normalized;

/* Helpers */
let im_rules = ref([]);
let local_var_counter = ref(0);
let source_program = ref("");
let entry_name = ref("");


let rec map_to_im_rules = (simple: B.simple, rules: list((string, B.simple))): option(string) => {
   switch(rules) {
   | [] => None
   | [(name, im_rule), ...rest] => {
      if (simple == im_rule) {
         Some(name)
      } else {
         map_to_im_rules(simple, rest)
      }
   }
   }
}

let generate_atom_local_var = (_: B.atom): string => {
  incr(local_var_counter);
  "local_var" ++ string_of_int(local_var_counter^)
}


/* Generators */
let generate_atom = (atom: B.atom): string => {
   switch(atom) {
   | B.SYMBOL(ident) =>  ident
   | B.STRING(string) => string
   | _ => failwith("Unhandle case in generated_atom_parsers")
   }
}

let set_entry_name = (rules: list(B.rule)) => {
   List.map(((name:string, body: B.rule_body)) => {
      switch(body) {
      | B.REPEAT(B.ATOM(atom)) => {
         let atom_name = generate_atom(atom);
         if (name == source_program^) {
            entry_name := atom_name
         }
         atom_name
      }
      | _ => ""
      }
   }, rules);
}

let generate_atom_json_type_matchers = (atom: B.atom): string => {
   switch(atom) {
   | B.SYMBOL(_) =>
      spf("
      J.Object([(\"type\", J.String(\"%s\")),
               (\"children\", %s)])",
      generate_atom(atom),
      generate_atom_local_var(atom))
   | B.STRING(_) =>
      spf("
      J.Object([(\"type\", J.String(\"%s\")),
               (\"children\", _)])",
      generate_atom(atom))
   | B.TOKEN => failwith("Unhandle case in generated_atom_parsers")
   }
}

let generate_atom_func_calls = (atom: B.atom) => {
   switch(atom) {
   | B.SYMBOL(_) => spf("parse_%s(%s)",generate_atom(atom), generate_atom_local_var(atom))
   | B.STRING(_) => spf("\"%s\"", generate_atom(atom))
   | B.TOKEN => failwith("Unhandle case in generated_atom_parsers")
   }
}

let generate_atom_seq = (atoms: list(B.atom)): string => {
   local_var_counter := 0;
   let generated_atoms = List.map(generate_atom_json_type_matchers, atoms);

   local_var_counter := 0;
   let generated_atom_parsers = List.map(generate_atom_func_calls, atoms);

   let im_type_name = map_to_im_rules(B.SEQ(atoms), im_rules^);

   let im_type_str = switch(im_type_name) {
      | Some(rule_name) => spf("%s((%s))", rule_name, String.concat(",", generated_atom_parsers))
      | None => spf("(%s)", String.concat(",", generated_atom_parsers))
   }
   spf("
   | J.Array([%s
      ]) => %s",
   String.concat(",", generated_atoms),
   im_type_str)
}

let generate_simple = (parent_name: string, simple: B.simple): string => {
   switch(simple) {
   | B.ATOM(atom) => {
      let simple_name = generate_atom(atom);
      let im_type_name = map_to_im_rules(simple, im_rules^);
      let im_name = switch(im_type_name) {
      | Some(rule_name) => rule_name
      | None => ""
      }
      if (parent_name == entry_name^) {
         spf("
            | J.Object([(\"type\", J.String(\"%s\")),
                        (\"children\", xs)
            ]) => %s(parse_%s(xs))",
         simple_name, im_name, simple_name);
      } else {
         spf("
            | J.Array([
               J.Object([(\"type\", J.String(\"%s\")),
                        (\"children\", xs)
            ])]) => %s(parse_%s(xs))",
         simple_name, im_name, simple_name);
      }
   }
   | B.SEQ(atoms) => generate_atom_seq(atoms)
   }
}

let generate_recursive_parser = ((name:string, body: B.rule_body)): string => {
   switch(body) {
   | B.SIMPLE(B.ATOM(_)) => {
      /* Leaf node */
      spf("parse_%s = (json: J.json_type): token => {
      switch(json) {
         | J.Object([(\"type\", J.String(\"%s\")),
                     (\"children\", _)]) => \"%s\"
         | J.Array([]) => \"\"
         | _ => error(\"Bad token\", json)
      }
      }",
      name,
      name,
      name)
   }
   | B.SIMPLE(B.SEQ(xs)) => {
     spf("parse_%s = (json: J.json_type): %s => {
      switch(json) {%s
         | _ => error(\"Bad\", json)
      }
      }",
     name,
     name,
     generate_atom_seq(xs)
     )
   }
   | B.REPEAT(B.ATOM(atom)) => {
      spf("parse_%s = (json:  J.json_type): %s => {
            switch(json) {
               | J.Array(xs) =>  List.map(parse_%s, xs)
               | _ => error(\"Bad\", json)
               }
               }\n",
         name,
         name,
         generate_atom(atom),
      )
   }
   | B.CHOICE(simples) => {
      /* Check simple nodes against intermediate nodes list by structure
         if they match, return the intermediate node constructor
      */
      let simple_strs = List.map((simple) => generate_simple(name, simple), simples);
      spf("parse_%s = (json: J.json_type): %s => {
         switch(json) {%s
            | _ => error(\"Bad %s\", json)
         }
      }",
      name,
      name,
      String.concat("\n", simple_strs),
      name)
   }
   | _ => " TODO " ++ name
   }
}

let generate_parser_func = (rules: list((string, B.rule_body))): string => {
   let parser_simple_strings = List.map(generate_recursive_parser, rules);
   let parser_func_body = spf("
let rec %s\n"
   , String.concat("\nand ", parser_simple_strings));
   parser_func_body
}

/* Main */
let codegen = (nast: B.grammar, rules: list((string, B.simple)), generated_cst_filename: string): string => {
   let header = spf(
"/* DO NOT MODIFY MANUALLY:
Auto-generated by codegen_json_reader*/
open %s
open Common;
module J = Json_type;
let error = (s, json) => failwith(spf(\"Wrong format: %s, got: %s\",s,Json_io.string_of_json(json)));\n",
   generated_cst_filename, "%s", "%s");

   let entrypoint = spf("/*****************************************************************************/
/* Entrypoint */
/*****************************************************************************/
let parse = (file): Ast_arithmetic.program => {
    let json = Json_io.load_json(file);
    switch(json) {
    | J.Object(xs) => {
      let children = List.assoc(\"children\",xs);
      parse_%s(children)
    }
    | _ => error(\"Toplevel\", json);
    }
}", fst(nast));

   /* save im rules into global variable */
   im_rules := rules;
   source_program := fst(nast);
   let _ = set_entry_name(snd(nast));
   header ++ generate_parser_func(snd(nast)) ++ entrypoint;
}