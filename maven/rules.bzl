load("//maven:internal/maven_repositories.bzl", _maven_repositories = "maven_repositories")
load("//maven:internal/maven_repository.bzl", _maven_repository = "maven_repository")
load("//maven:internal/require.bzl", _require = "require")

maven_repositories = _maven_repositories
maven_repository = _maven_repository
require = _require
