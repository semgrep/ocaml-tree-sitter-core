module.exports = grammar({
    name: "token",
    rules: {
        program: $ => seq(
            token(
                seq(
                    repeat("a"),
                    choice("b", "yo")
                )
            ),
            // The following two nodes should be factored out, but the one
            // within token() above.
            seq(
                repeat("a"),
                choice("b", "yo")
            ),
            seq(
                repeat("a"),
                choice("b", "yo")
            )
        )
    }
});
