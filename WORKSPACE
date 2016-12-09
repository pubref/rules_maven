workspace(name = "org_pubref_rules_maven")

local_repository(
    name = "org_pubref_rules_require",
    path = "/Users/pcj/github/rules_require",
)

load("@org_pubref_rules_require//require:rules.bzl", "require_repositories")
require_repositories()

load("//maven:rules.bzl", "maven_repositories")
maven_repositories()
