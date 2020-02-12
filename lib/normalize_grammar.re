module A = Ast_grammar;
module B = Ast_grammar_normalized;

let counter = ref(0);
let gensym = () => {
  incr(counter);
  "intermediate" ++ string_of_int(counter^);
}

let rec normalize_to_atom = body => {
  switch (body) {
  | A.TOKEN => (B.TOKEN, [])
  | A.SYMBOL(name)=> (B.SYMBOL(name), [])
  /* Create intermediate symbol */
  | _ => {
    let fresh_ident = gensym();
    (B.SYMBOL(fresh_ident), [(fresh_ident, fst(normalize_body(body)))]);
    }
  }
}
and normalize_body = (rule_body) => {
  switch(rule_body) {
  | A.TOKEN =>
    (
      B.SIMPLE(B.ATOM(B.TOKEN)),
      []
    );
  | A.SYMBOL(name) =>
    (
      B.SIMPLE(B.ATOM(B.SYMBOL(name))),
      []
    );
  | A.SEQ(bodies) => {
      let xs = List.map(normalize_to_atom, bodies);
      let atoms = List.map(fst, xs);
      let intermediates = List.flatten(List.map(snd, xs));
      (B.SIMPLE(B.SEQ(atoms)), intermediates)
    };
  | A.CHOICE(bodies) => {
      let xs = List.map(normalize_to_atom, bodies);
      let atoms = List.map(fst, xs);
      let simples = List.map((atom) => B.ATOM(atom), atoms);
      let intermediates = List.flatten(List.map(snd, xs));
      (B.CHOICE(simples), intermediates)
  }
  | _ =>
    (
      B.SIMPLE(B.ATOM(B.TOKEN)),
      []
    );
  }
}

let normalize_rule = ((name, rule_body)) => {
  let (this_body, intermediates) = normalize_body(rule_body);
  let extra_rules = intermediates;
  [(name, this_body), ...extra_rules]
};

let normalize_rules = xs => List.flatten(List.map(normalize_rule, xs));

let normalize = ((name: string, rules)) => (name, normalize_rules(rules));