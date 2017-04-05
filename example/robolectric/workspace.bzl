_SDK_BZL = """
# Generated file, do not edit
def android_sdk(
    name = "androidsdk",
    path = "{path}",
    api_level = {api_level},
    build_tools_version = "{build_tools_version}"
):
    native.android_sdk_repository(
        name = name,
        path = path,
        api_level = api_level,
        build_tools_version = build_tools_version,
    )
"""

def _local_rules_maven_repository_impl(rtx):
    # Get the absolute path if the 'source' label and convert to a string
    path = "%s" % rtx.path(rtx.attr._source)

    # Convert /Users/pcj/github/rules_maven/example/robolectric/workspace.bzl
    # to      /Users/pcj/github/rules_maven/maven
    parts = path.split('/')
    maven_dir = "/".join(parts[0:-3] + ["maven"])

    # Symlink it to expose this directory here.
    rtx.symlink('/%s' % maven_dir, 'maven')

    # Create a new utility bzl file to load an android sdk
    rtx.execute(['mkdir', 'android'])

    rtx.file('android/BUILD', "")

    # Create a new bzl file to load an android sdk
    rtx.file('android/sdk.bzl', _SDK_BZL.format(
        path = rtx.attr.android_sdk_path,
        api_level = rtx.attr.android_api_level,
        build_tools_version = rtx.attr.android_build_tools_version,
    ))


local_rules_maven_repository = repository_rule(
    implementation = _local_rules_maven_repository_impl,
    attrs = {
        # We need to discover the absolute path of any file in the
        # current directory to symlink the parent workspace maven dir.
        "_source": attr.label(
            default = Label("//:workspace.bzl")
        ),
        "android_sdk_path": attr.string(
            # This is the default path on Travis CI
            default = "/usr/local/android-sdk",
        ),
        "android_api_level": attr.string(
            # This is the default on Travis CI
            default = "24",
        ),
        "android_build_tools_version": attr.string(
            # This is the default on Travis CI
            default = "24.0.0",
        )
    },
)
