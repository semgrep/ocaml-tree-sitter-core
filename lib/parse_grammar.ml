open Common
open Ast_grammar
module J = Json_type
let error s json =
  failwith (spf "Wrong format: %s, got: %s" s (Json_io.string_of_json json))
let rec parse_body json =
  match json with
  | ((J.Object
      (("type", ((J.String ("REPEAT"))[@explicit_arity ]))::("content", json)::[]))
      [@explicit_arity ]) -> ((REPEAT ((parse_body json)))[@explicit_arity ])
  | ((J.Object
      (("type", ((J.String ("CHOICE"))[@explicit_arity ]))::("members",
                                                             ((J.Array
                                                             (xs))[@explicit_arity
                                                                    ]))::[]))
      [@explicit_arity ]) -> ((CHOICE ((List.map parse_body xs)))
      [@explicit_arity ])
  | ((J.Object
      (("type", ((J.String ("SEQ"))[@explicit_arity ]))::("members",
                                                          ((J.Array
                                                          (xs))[@explicit_arity
                                                                 ]))::[]))
      [@explicit_arity ]) -> ((SEQ ((List.map parse_body xs)))
      [@explicit_arity ])
  | ((J.Object
      (("type", ((J.String ("SYMBOL"))[@explicit_arity ]))::("name",
                                                             ((J.String
                                                             (name))[@explicit_arity
                                                                    ]))::[]))
      [@explicit_arity ]) -> ((SYMBOL (name))[@explicit_arity ])
  | ((J.Object
      (("type", ((J.String ("STRING"))[@explicit_arity ]))::("value",
                                                             ((J.String
                                                             (name))[@explicit_arity
                                                                    ]))::[]))
      [@explicit_arity ]) -> ((STRING (name))[@explicit_arity ])
  | ((J.Object
      (("type", ((J.String ("PATTERN"))[@explicit_arity ]))::("value",
                                                              ((J.String
                                                              (name))
                                                              [@explicit_arity
                                                                ]))::[]))
      [@explicit_arity ]) -> ((PATTERN (name))[@explicit_arity ])
  | ((J.Object
      (("type", ((J.String
        (("PREC"|"PREC_LEFT"|"PREC_RIGHT"|"PREC_DYNAMIC")))[@explicit_arity ]))::
       ("value", _)::("content", json)::[]))[@explicit_arity ])
      -> parse_body json
  | ((J.Object
      (("type", ((J.String ("FIELD"))[@explicit_arity ]))::("name",
                                                            ((J.String
                                                            (_name))[@explicit_arity
                                                                    ]))::
       ("content", json)::[]))[@explicit_arity ])
      -> parse_body json
  | _ -> error "parse_body" json
let parse_rule (name, json) = (name, (parse_body json))
let parse_rules xs = List.map parse_rule xs
let parse_grammar json =
  match json with
  | ((J.Object ((start, x)::rest))[@explicit_arity ]) ->
      (start, (parse_rules ((start, x) :: rest)))
  | _ -> error "Grammar" json
let parse file =
  let json = Json_io.load_json file in
  match json with
  | ((J.Object (xs))[@explicit_arity ]) ->
      let rules = List.assoc "rules" xs in parse_grammar rules
  | _ -> error "Top" json