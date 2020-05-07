type program = list(intermediate1)

and intermediate1 = 
 | Intermediate_type1(assignment_statement)
 | Intermediate_type2(expression_statement)

and assignment_statement = (variable, string /* = */, expression, string /* ; */)

and expression_statement = (expression, string /* ; */)

and expression = 
 | Intermediate_type3(variable)
 | Intermediate_type4(number)
 | Intermediate_type5((expression, string /* + */, expression))
 | Intermediate_type6((expression, string /* - */, expression))
 | Intermediate_type7((expression, string /* * */, expression))
 | Intermediate_type8((expression, string /* / */, expression))
 | Intermediate_type9((expression, string /* ^ */, expression))

and comment = string
and number = string
and variable = string
;
