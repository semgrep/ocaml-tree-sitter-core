module A = Ast_grammar;
module B = Ast_grammar_normalized;

let counter = ref(0);
let gensym = () => {
  incr(counter);
  "intermediate" ++ string_of_int(counter^);
}

let rec normalize_to_simple = (body: A.rule_body): (B.simple, list(A.rule)) => {
  switch (body) {
<<<<<<< HEAD
  | A.TOKEN | A.IMMEDIATE_TOKEN | A.BLANK | A.SYMBOL(_) | A.STRING(_) | A.PATTERN(_) => {
=======
  | A.TOKEN | A.SYMBOL(_) => {
>>>>>>> c34f70b... rebase fixes
    let (atom, rest) = normalize_to_atom(body);
    (B.ATOM(atom), rest)
  }
  | A.SEQ(bodies) => {
    let xs = List.map(normalize_to_atom, bodies);
    let atoms = List.map(fst, xs);
    let intermediates = List.flatten(List.map(snd, xs));
    (B.SEQ(atoms), intermediates)
  }
  /* Create intermediate symbol */
  | _ => {
    let fresh_ident = gensym();
    (B.ATOM(B.SYMBOL(fresh_ident)), [(fresh_ident, body)]);
    }
  }
}
and normalize_to_atom = (body: A.rule_body): (B.atom, list(A.rule)) => {
  switch (body) {
  | A.TOKEN | A.IMMEDIATE_TOKEN | A.BLANK => (B.TOKEN, [])
  | A.SYMBOL(name) | A.STRING(name) | A.PATTERN(name)=> (B.SYMBOL(name), [])
  /* Create intermediate symbol */
  | _ => {
    let fresh_ident = gensym();
    (B.SYMBOL(fresh_ident), [(fresh_ident, body)]);
    }
  }
}
and normalize_body = (rule_body: A.rule_body): (B.rule_body, list(A.rule)) => {
  switch(rule_body) {
  | A.IMMEDIATE_TOKEN | A.BLANK | A.TOKEN | A.SYMBOL(_) | A.STRING(_) | A.PATTERN(_) => {
      let (simple, rest) = normalize_to_simple(rule_body);
      (B.SIMPLE(simple), rest);
    }
  | A.SEQ(bodies) => {
      let xs = List.map(normalize_to_atom, bodies);
      let atoms = List.map(fst, xs);
      let intermediates = List.flatten(List.map(snd, xs));
      (B.SIMPLE(B.SEQ(atoms)), intermediates)
    };
  | A.CHOICE(bodies) => {
    switch (List.rev(bodies)) {
    | [A.BLANK] => failwith("Impossible, a single BLANK in a CHOICE")
    | [A.BLANK, other_body] => {
      let (simple, rest) = normalize_to_simple(other_body);
      (B.OPTION(simple), rest)
    }
    | [A.BLANK, ...other_bodies] => {
      /* this will create a gensymed ATOM(SYMBOL) for this CHOICE */
      let (simple, rest) = normalize_to_simple(A.CHOICE(other_bodies));
      (B.OPTION(simple), rest)
    }
    | _ => {
      let xs = List.map(normalize_to_simple, bodies);
      let simples = List.map(fst, xs);
      let intermediates = List.flatten(List.map(snd, xs));
      (B.CHOICE(simples), intermediates)
    }
    }
  }
  | A.REPEAT(body) => {
      let (simple, rest) = normalize_to_simple(body);
      (B.REPEAT(simple), rest)
    }
  | _ => failwith("TODO");
  };
}
and normalize_rule = ((name, rule_body): A.rule): (list(B.rule)) => {
  let (this_body, intermediates) = normalize_body(rule_body);
  let this_rule = (name, this_body);
  if (intermediates == []) {
    [this_rule]
  } else {
    let other_rules = List.flatten(List.map(normalize_rule, intermediates));
    [this_rule, ...other_rules]
  }
}
let normalize_rules = (xs: list(A.rule)): (list(B.rule)) => List.stable_sort(
  /* Sort rules by the name to guarantee deterministism */
  (a,b) => String.compare(fst(a),fst(b)),
  List.flatten(List.map(normalize_rule, xs)
));

let normalize = ((name, rules): A.grammar): (B.grammar) => {
  counter := 0;
  (name, normalize_rules(rules))
};