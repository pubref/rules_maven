#
# Repository rule implementation that avoids the need for a
# `local_repository` rule referencing the parent WORKSPACE.
#

def _local_rules_maven_repository_impl(rtx):
    # Get the absolute path if the 'source' label and convert to a string
    path = "%s" % rtx.path(rtx.attr._source)

    # Convert /Users/pcj/github/rules_maven/example/robolectric/local_rules_maven_repository.bzl
    # to      /Users/pcj/github/rules_maven/maven
    parts = path.split('/')
    maven_dir = "/".join(parts[0:-3] + ["maven"])

    # Symlink it to expose this directory here.
    rtx.symlink('/%s' % maven_dir, 'maven')


local_rules_maven_repository = repository_rule(
    implementation = _local_rules_maven_repository_impl,
    attrs = {
        # We need to discover the absolute path of any file in the
        # current directory to symlink the parent workspace maven dir.
        "_source": attr.label(
            default = Label("//:local_rules_maven_repository.bzl")
        ),
    },
)
