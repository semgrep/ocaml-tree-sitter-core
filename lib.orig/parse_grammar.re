/* Yoann Padioleau
 *
 * Copyright (C) 2020 r2c
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License (GPL)
 * version 2 as published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * file license.txt for more details.
 */
open Common;
open Ast_grammar
module J = Json_type;

let error = (s, json) => failwith(spf("Wrong format: %s, got: %s",s,Json_io.string_of_json(json)));

let rec parse_body = json =>
    switch(json) {
    | J.Object([("type", J.String("REPEAT")),
                ("content", json)]) => REPEAT(parse_body(json))
    | J.Object([("type", J.String("CHOICE")),
                ("members", J.Array(xs))]) => CHOICE(List.map(parse_body,xs))
    | J.Object([("type", J.String("SEQ")),
                ("members", J.Array(xs))]) => SEQ(List.map(parse_body,xs))

    | J.Object([("type", J.String("SYMBOL")),
                ("name", J.String(name))]) => SYMBOL(name)
    | J.Object([("type", J.String("STRING")),
                ("value", J.String(name))]) => STRING(name)
    | J.Object([("type", J.String("PATTERN")),
                ("value", J.String(name))]) => PATTERN(name)

    /* skip over those */
    | J.Object([("type", J.String("PREC" | "PREC_LEFT" | "PREC_RIGHT" | "PREC_DYNAMIC")),
                ("value", _),
                ("content", json)
                ]) => parse_body(json)
    /* could want to maintain this information */
    | J.Object([("type", J.String("FIELD")),
                ("name", J.String(_name)),
                ("content", json)]) => parse_body(json)

    | _ => error("parse_body", json)
    };

let parse_rule = ((name, json)) => (name, parse_body(json));
let parse_rules = xs => List.map(parse_rule, xs);
let parse_grammar = json => {
    switch(json) {
    | J.Object([(start, x), ...rest]) => (start, parse_rules([(start,x), ...rest]));
    | _ => error("Grammar", json);
    }
};

/*****************************************************************************/
/* Entrypoint */
/*****************************************************************************/
let parse = file => {
    let json = Json_io.load_json(file);
    switch(json) {
    | J.Object(xs) => {
            let rules = List.assoc("rules",xs);
            parse_grammar(rules)
        }
    | _ => error("Top", json);
    }
}
