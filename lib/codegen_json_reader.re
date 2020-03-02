open Common;
module N = Ast_grammar_normalized;

/* Helpers */
let im_rules = ref([]);
let local_var_counter = ref(0);
let source_program = ref("");
let entry_name = ref("");


let rec map_to_im_rules = (simple: N.simple, rules: list((string, N.simple))): option(string) => {
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

let generate_atom_local_var = (_: N.atom): string => {
  incr(local_var_counter);
  "local_var" ++ string_of_int(local_var_counter^)
}


/* Generators */
let generate_atom = (atom: N.atom): string => {
   switch(atom) {
   | N.SYMBOL(ident) =>  ident
   | N.STRING(string) => string
   | N.TOKEN => failwith("Unhandle case in generated_atom_parsers")
   }
}

let set_entry_name = (rules: list(N.rule)) => {
   List.map(((name:string, body: N.rule_body)) => {
      switch(body) {
      | N.REPEAT(N.ATOM(atom)) => {
         let atom_name = generate_atom(atom);
         if (name == source_program^) {
            entry_name := atom_name
         }
         atom_name
      }
      | _ => "" /* this is to skip over the rest of the cases. Sadly there is no `continue` for ocaml */
      }
   }, rules);
}

let generate_atom_json_type_matchers = (atom: N.atom): string => {
   switch(atom) {
   | N.SYMBOL(_) =>
      spf("
      J.Object([(\"type\", J.String(\"%s\")),
               (\"children\", %s)])",
      generate_atom(atom),
      generate_atom_local_var(atom))
   | N.STRING(_) =>
      spf("
      J.Object([(\"type\", J.String(\"%s\")),
               (\"children\", _)])",
      generate_atom(atom))
   | N.TOKEN => failwith("Unhandle case in generated_atom_parsers")
   }
}

let generate_atom_func_calls = (atom: N.atom) => {
   switch(atom) {
   | N.SYMBOL(_) => spf("parse_%s(%s)",generate_atom(atom), generate_atom_local_var(atom))
   | N.STRING(_) => spf("\"%s\"", generate_atom(atom))
   | N.TOKEN => failwith("Unhandle case in generated_atom_parsers")
   }
}

let generate_atom_seq = (atoms: list(N.atom)): string => {
   local_var_counter := 0;
   let generated_atoms = List.map(generate_atom_json_type_matchers, atoms);

   local_var_counter := 0;
   let generated_atom_parsers = List.map(generate_atom_func_calls, atoms);

   let im_type_name = map_to_im_rules(N.SEQ(atoms), im_rules^);

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

let generate_simple = (parent_name: string, simple: N.simple): string => {
   switch(simple) {
   | N.ATOM(atom) => {
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
   | N.SEQ(atoms) => generate_atom_seq(atoms)
   }
}

let generate_recursive_parser = ((name:string, body: N.rule_body)): string => {
   switch(body) {
   | N.SIMPLE(N.ATOM(_)) => {
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
   | N.SIMPLE(N.SEQ(xs)) => {
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
   | N.REPEAT(N.ATOM(atom)) => {
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
   | N.CHOICE(simples) => {
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

let generate_parser_func = (rules: list((string, N.rule_body))): string => {
   let parser_simple_strings = List.map(generate_recursive_parser, rules);
   let parser_func_body = spf("
let rec %s\n"
   , String.concat("\nand ", parser_simple_strings));
   parser_func_body
}

/* Main */
let codegen = (nast: N.grammar, rules: list((string, N.simple)), generated_cst_filename: string): string => {
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