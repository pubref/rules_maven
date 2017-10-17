
genquery(
    name = "genson_compile_deps",
    expression = "deps(@genson//:compile)",
    scope = ["@genson//:compile"],
)

py_test(
    name = "test_omit",
    srcs = ["test_omit.py"],
    size = "small",
    data = [":genson_compile_deps"],
)
