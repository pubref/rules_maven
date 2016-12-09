def _require_toolchain_impl(rtx):
    rtx.file("BUILD", "exports_files(['require.bzl'])");
    rtx.symlink(rtx.path(rtx.attr._require_bzl), "require.bzl");

require_toolchain = repository_rule(
    implementation = _require_toolchain_impl,
    attrs = {
        "_require_bzl": attr.label(
            default = Label("//maven:internal/require.bzl"),
        )
    },
)
