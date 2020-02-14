module A = Ast_grammar;
module B = Ast_grammar_normalized;

let counter = ref(0);
let gensym = () => {
  incr(counter);
  "intermediate" ++ string_of_int(counter^);
}

let rec normalize_to_simple = body => {
  switch (body) {
  | A.TOKEN => (B.ATOM(B.TOKEN), [])
  | A.SYMBOL(name)=> (B.ATOM(B.SYMBOL(name)), [])
  /* Create intermediate symbol */
  | _ => {
    let fresh_ident = gensym();
    (B.ATOM(B.SYMBOL(fresh_ident)), [(fresh_ident, body)]);
    }
  }
}
and normalize_to_atom = body => {
  switch (body) {
  | A.TOKEN => (B.TOKEN, [])
  | A.SYMBOL(name)=> (B.SYMBOL(name), [])
  /* Create intermediate symbol */
  | _ => {
    let fresh_ident = gensym();
    (B.SYMBOL(fresh_ident), [(fresh_ident, body)]);
    }
  }
}
and normalize_body = (rule_body) => {
  switch(rule_body) {
  | A.TOKEN => {
      let (simple, rest) = normalize_to_simple(A.TOKEN);
      (B.SIMPLE(simple), rest);
    }
  | A.SYMBOL(name) => {
      let (simple, rest) = normalize_to_simple(A.SYMBOL(name));
      (B.SIMPLE(simple), rest);
    }
  | A.SEQ(bodies) => {
      let xs = List.map(normalize_to_atom, bodies);
      let atoms = List.map(fst, xs);
      let intermediates = List.flatten(List.map(snd, xs));
      (B.SIMPLE(B.SEQ(atoms)), intermediates)
    };
  | A.CHOICE(bodies) => {
      let xs = List.map(normalize_to_simple, bodies);
      let simples = List.map(fst, xs);
      let intermediates = List.flatten(List.map(snd, xs));
      (B.CHOICE(simples), intermediates)
    };
  | _ =>
    (
      B.SIMPLE(B.ATOM(B.TOKEN)),
      []
    );
  };
}
and normalize_rule = ((name, rule_body)) => {
  let (this_body, intermediates) = normalize_body(rule_body);
  let new_rules = ref([(name, this_body)]);
  let s = Stack.create();
  List.iter(item => Stack.push(item, s), intermediates);
  while (!Stack.is_empty(s)) {
    let (rname, body) = Stack.pop(s);
    let (new_body, inters) = normalize_body(body);
    new_rules := [(rname, new_body), ...new_rules^];
    List.iter(item => Stack.push(item, s), inters);
  };
  [...new_rules^]
}
let normalize_rules = xs => List.stable_sort(
  /* Sort rules by the name to guarantee deterministism */
  (a,b) => String.compare(fst(a),fst(b)),
  List.flatten(List.map(normalize_rule, xs)
));

let normalize = ((name: string, rules)) => {
  counter := 0;
  (name, normalize_rules(rules))
};