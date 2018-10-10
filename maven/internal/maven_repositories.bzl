load("//maven:internal/require.bzl", "require")
load("//maven:internal/require_toolchain.bzl", "require_toolchain")

GRADLE_VERSION = "4.10.2"

GRADLE_BUILD_FILE = """
java_import(
  name = "launcher",
  jars = ["lib/gradle-launcher-{version}.jar"],
)
filegroup(
  name = "launcher.jar",
  srcs = ["lib/gradle-launcher-{version}.jar"],
)
exports_files(["lib/gradle-launcher-{version}.jar"])
""".format(version = GRADLE_VERSION)

DEPS = {
    "gradle_distribution": {
        "rule": "new_http_archive",
        "url": "https://services.gradle.org/distributions/gradle-%s-bin.zip" % GRADLE_VERSION,
        "sha256": "",
        "strip_prefix": "gradle-" + GRADLE_VERSION,
        "build_file_content": GRADLE_BUILD_FILE,
    },
}

def maven_repositories(deps = DEPS, overrides = {}, excludes = [], verbose = 0):
    # Setup the toolchain repository that we always know the external name of
    # the require script.
    require_toolchain(name = "org_pubref_require_toolchain");
    require([
        "gradle_distribution",
    ], deps, overrides, excludes, verbose)
