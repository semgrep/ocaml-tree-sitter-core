module.exports = grammar({
    name: "opt_choice_opt",
    rules: {
        program: $ => optional(
            choice(
                optional($.number)
            )
        ),
        number: $ => /[0-9]+/
    }
});
