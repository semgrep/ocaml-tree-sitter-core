open Common;

let normalize_body = (rule_body) => (rule_body);

let normalize_rule = ((name, rule_body)) => (name, normalize_body(rule_body));

let normalize_rules = xs => List.map(normalize_rule, xs);

let normalize = ast => {
  switch(ast) {
  | (_, rules) => {
      pr2(spf("Length of rules %s \n", string_of_int(List.length(rules))));
      let normalized_rules = normalize_rules(rules);
      pr2(spf("Length of normalized rules %s \n", string_of_int(List.length(normalized_rules))));
      raise(Todo);
    }
  }
}