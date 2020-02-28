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
open Ast_arithmetic;
module J = Json_type;

let error = (s, json) => failwith(spf("Wrong format: %s, got: %s",s,Json_io.string_of_json(json)));

let rec parse_token = (json: J.json_type): token => {
  switch(json) {
    | J.Object([("type", J.String("comment")),
                ("children", _)]) => "comment"
    | J.Object([("type", J.String("number")),
                ("children", _)]) => "number"
    | J.Object([("type", J.String("variable")),
                ("children", _)]) => "variable"
    | _ => failwith("Bat token")
  }
}

and parse_expression = (json: J.json_type): expression => {
    switch(json) {
    | J.Array([
        J.Object([("type", J.String("variable")),
            ("children", _)
        ])
      ]) => Intermediate_type3("variable")
    | J.Array([
        J.Object([("type", J.String("number")),
            ("children", _)
        ])
      ]) => Intermediate_type4("number")
    | J.Array([
        J.Object([("type", J.String("expression")),
            ("children", exp1)
        ]),
        J.Object([("type", J.String("+")),
            ("children", _)
        ]),
        J.Object([("type", J.String("expression")),
            ("children", exp2)
        ]),
      ]) => Intermediate_type5((parse_expression(exp1), "+", parse_expression(exp2)))
    | J.Array([
        J.Object([("type", J.String("expression")),
            ("children", exp1)
        ]),
        J.Object([("type", J.String("-")),
            ("children", _)
        ]),
        J.Object([("type", J.String("expression")),
            ("children", exp2)
        ]),
      ]) => Intermediate_type6((parse_expression(exp1), "-", parse_expression(exp2)))
    | J.Array([
        J.Object([("type", J.String("expression")),
            ("children", exp1)
        ]),
        J.Object([("type", J.String("*")),
            ("children", _)
        ]),
        J.Object([("type", J.String("expression")),
            ("children", exp2)
        ]),
      ]) => Intermediate_type7((parse_expression(exp1), "*", parse_expression(exp2)))
    | J.Array([
        J.Object([("type", J.String("expression")),
            ("children", exp1)
        ]),
        J.Object([("type", J.String("/")),
            ("children", _)
        ]),
        J.Object([("type", J.String("expression")),
            ("children", exp2)
        ]),
      ]) => Intermediate_type8((parse_expression(exp1), "/", parse_expression(exp2)))
    | J.Array([
        J.Object([("type", J.String("expression")),
            ("children", exp1)
        ]),
        J.Object([("type", J.String("^")),
            ("children", _)
        ]),
        J.Object([("type", J.String("expression")),
            ("children", exp2)
        ]),
      ]) => Intermediate_type9((parse_expression(exp1), "^", parse_expression(exp2)))
    | _ =>  failwith("Bad expression")
    }
}

and parse_assignment_statement = (json): assignment_statement => {
  switch(json) {
  | J.Array([
      J.Object([("type", J.String("variable")),
        ("children", var)
      ]),
      J.Object([("type", J.String("=")),
        ("children", eq)
      ]),
      J.Object([("type", J.String("expression")),
        ("children", xs)
      ]),
      J.Object([("type", J.String(";")),
        ("children", colon)
      ]),
    ]) => (parse_token(var), parse_token(eq), parse_expression(xs), parse_token(colon))
  | _ => failwith("Bad expression_statement")
  }
}

and parse_expression_statement = (json:  J.json_type): expression_statement => {
  switch(json) {
  | J.Array([
      J.Object([("type", J.String("expression")),
        ("children", xs)
      ]),
      J.Object([("type", J.String(";")),
        ("children", _)
      ]),
    ]) => (parse_expression(xs), ";")
  | _ => failwith("Bad expression_statement")
  }
}


and parse_body = (json: J.json_type): intermediate1 =>
{
    switch(json) {
    | J.Object([("type", J.String("expression_statement")),
                ("children", xs)]) => Intermediate_type2(parse_expression_statement(xs))
    | J.Object([("type", J.String("assignment_statement")),
                ("children", xs)]) => Intermediate_type1(parse_assignment_statement(xs))
    | _ =>  error("Todo general", json)
    };
}

and parse_children = (xs: J.json_type): list(intermediate1) => {
    switch(xs) {
    | J.Array(xs) => List.map(parse_body, xs)
    | _ => error("Top parse_children", xs)
    }
}

/*****************************************************************************/
/* Entrypoint */
/*****************************************************************************/
let parse = (file): Ast_arithmetic.program => {
    let json = Json_io.load_json(file);
    switch(json) {
    | J.Object(xs) => {
      let children = List.assoc("children",xs);
      parse_children(children)
    }
    | _ => error("Toplevel", json);
    }
}
