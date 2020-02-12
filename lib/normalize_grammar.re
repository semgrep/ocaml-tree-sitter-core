open Common;

let normalize_to_simple = body => {
  switch (body) {
  | Ast_grammar.TOKEN =>
    Ast_grammar_normalized.ATOM(
      Ast_grammar_normalized.TOKEN
    );
  | Ast_grammar.SYMBOL(name)=>
    Ast_grammar_normalized.ATOM(
      Ast_grammar_normalized.SYMBOL(name)
    );
  /* Ignore rest */
  | _ => {
    print_string("Inside normalize_to_simple\n");
    raise(Todo);
  }
  }
}

let normalize_to_atom = body => {
  switch (body) {
  | Ast_grammar.TOKEN =>
    Ast_grammar_normalized.TOKEN
  | Ast_grammar.SYMBOL(name)=>
    Ast_grammar_normalized.SYMBOL(name)
  /* Ignore rest */
  | _ => {
    print_string("Inside normalize_to_atom\n");
    raise(Todo);
  }
  }
}

let normalize_body = (rule_body) => {
  switch(rule_body) {
  | Ast_grammar.TOKEN =>
    Ast_grammar_normalized.SIMPLE(
      Ast_grammar_normalized.ATOM(
        Ast_grammar_normalized.TOKEN
      )
    );
  | Ast_grammar.SYMBOL(name) =>
    Ast_grammar_normalized.SIMPLE(
      Ast_grammar_normalized.ATOM(
        Ast_grammar_normalized.SYMBOL(name)
      )
    );
  | Ast_grammar.SEQ(bodies) =>
    Ast_grammar_normalized.SIMPLE(
      Ast_grammar_normalized.SEQ(
        List.map(normalize_to_atom, bodies)
      )
    );
  | Ast_grammar.CHOICE(bodies) =>
    Ast_grammar_normalized.CHOICE(
      List.map(normalize_to_simple, bodies)
    );
  | _ =>
    Ast_grammar_normalized.SIMPLE(
      Ast_grammar_normalized.ATOM(
        Ast_grammar_normalized.TOKEN
      )
    );
  }
}

let normalize_rule = ((name, rule_body)) => (name, normalize_body(rule_body));

let normalize_rules = xs => List.map(normalize_rule, xs);

let normalize = ast => {
  switch(ast) {
  | (name, rules) => {
      (name, normalize_rules(rules));
    }
  }
}