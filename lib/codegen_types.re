module B = Ast_grammar_normalized;

/* TODO: Not sure if we need immediate types as well
let counter = ref(0);
let gen_intermediate_type = () => {
  incr(counter);
  "Intermediate_type" ++ string_of_int(counter^);
}
*/

let codegen_atom = (atom: B.atom): string => {
   switch(atom) {
   | B.TOKEN => "" /* ignore tokens */
   | B.SYMBOL(name) => name ++ "(string)"
   }
}

let codegen_simple =  (simple: B.simple): string => {
   switch(simple) {
   | B.ATOM(atom) => codegen_atom(atom)
   | B.SEQ(atoms) => {
      /* codegen: (A,B,C,...) */
      let atom_strs = List.map(codegen_atom, atoms);
      "(" ++ String.concat(", ", atom_strs) ++ ")"
      }
   }
}

let codegen_rule = ((name, rule_body): B.rule): string => {
   switch (rule_body) {
   | B.SIMPLE(simple) => {
      let rhs = codegen_simple(simple);
      "type " ++ name ++ " = " ++ rhs
      }
   | B.CHOICE(simples) => {
      /* codegen: A(...) | B(...) */
      let rhs = List.map(codegen_simple, simples);
      /* TODO: Not sure if we need immediate types as well
      let im_types = List.map(
         (im_type: string) => gen_intermediate_type() ++ "(" ++ im_type ++ ")",
         rhs
      );
      */
      "type " ++ name ++ " = " ++ String.concat(" | ", rhs);
   }
   | B.REPEAT(simple) => {
      /* codegen: list(x) */
      let rhs = codegen_simple(simple);
      "type " ++ name ++ " = " ++ "list(" ++ rhs ++ ")"
   }
   | B.OPTION(simple) => {
      /* codegen: option(...) */
      let rhs = codegen_simple(simple);
      "type " ++ name ++ " = " ++ "option(" ++ rhs ++ ")"
   }
   }
}

let codegen_rules = (xs: list(B.rule)): (list(string)) => {
   List.map(codegen_rule, xs)
}

let codegen = ((_, rules): B.grammar): (string) => {
  let code_header = "";
  let rule_strs = codegen_rules(rules);
  code_header ++ String.concat(";\n", List.rev(rule_strs)) ++ ";";
}
