module.exports = grammar({
    name: "ts",
    rules: {
        program: $ => optional(
            choice(
                optional($.number)
            )
        ),
        number: $ => /[0-9]+/
    }
});
