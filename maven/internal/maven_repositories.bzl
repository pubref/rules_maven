load("@org_pubref_rules_require//require:rules.bzl", "require")

GRADLE_VERSION = "3.2.1"

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
    require([
        "gradle_distribution",
    ], deps, overrides, excludes, verbose)
