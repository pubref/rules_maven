# `rules_maven` [![Build Status](https://travis-ci.org/pubref/rules_maven.svg?branch=master)](https://travis-ci.org/pubref/rules_maven)

[Bazel][bazel-home] rules for working with transitive maven dependencies.

## Rules

| Name                     | Description |
| -------------------: | -----------: | --------: | -------- |
| [maven_repositories](#maven_repositories)  | Load dependencies for this repo. |
| [maven_repository](#maven_repository)  | Declare an external workspace that defines transitive maven dependencies. |

## Usage

### 1. Add rules_require and rules_maven to your WORKSPACE

This repository depends on [rules_require](https://github.com/pubref/rules_require).

```python
git_repository(
  name = "org_pubref_rules_require",
  remote = "https://github.com/pubref/rules_require",
  commit = HEAD, # replace with latest version
)

load("@org_pubref_rules_require//require:rules.bzl", "require_repositories")
require_repositories()

git_repository(
  name = "org_pubref_rules_maven",
  remote = "https://github.com/pubref/rules_maven",
  commit = HEAD, # replace with latest version
)

load("@org_pubref_rules_maven//maven:rules.bzl", "maven_repositories")
maven_repositories()
```

### 2. Define a maven_repository for a transitive set of maven artifacts in your WORKSPACE.

```python
maven_repository(
    name = "jetty",
    artifacts = [
        "org.eclipse.jetty:jetty-server:9.3.10.v20160621",
        "org.eclipse.jetty:jetty-server:9.3.10.v20160621",
        "org.eclipse.jetty:jetty-jmx:9.3.10.v20160621",
        "org.eclipse.jetty:jetty-plus:9.3.10.v20160621",
        "org.eclipse.jetty:jetty-jndi:9.3.10.v20160621",
        "org.eclipse.jetty:jetty-webapp:9.3.10.v20160621",
        "org.eclipse.jetty.websocket:websocket-servlet:9.3.10.v20160621",
        "org.eclipse.jetty.websocket:javax-websocket-client-impl:9.3.10.v20160621",
        "org.eclipse.jetty.websocket:javax-websocket-server-impl:9.3.10.v20160621",
    ],
)
```

Given this repository rule defintion, `rules_maven` will create a
`build.gradle` file, call `gradle dependencies`, parse the output of
this and translate it to a flattened set of `maven_jar` rules.

Three files are written in `($bazel info output_base)/external/jetty`:

1. `rules.bzl`: this file contains require definitions over the
   transitive closure of the maven jar dependency tree.  A separate
   `java_library` rule is defined foreach gradle configuration (`compile`,

### 3. Load the generated `@jetty//:rules.bzl` in your WORKSPACE and invoke the desired configuration.

> You'll likely want to alias the loaded function into a more specific
> name within your workspace

```python
load("@jetty//:rules.bzl", jetty_runtime = "runtime")
jetty_runtime()
```

### 4. Depend on the java_library rule for the desired configuration.

> You'll likely want to alias the loaded function into a more specific
> name within your workspace

```python
java_binary(
  name = "app",
  main_class = "example.App",
  deps = ["@jetty//:runtime"],
)
```

# Credits

Depending on a rule that is defined earlier in the workspace is now
possible due to the interleaved loading and analysis phases of bazel.
Previously, this approach would not work.  Thanks Bazel team for
making this happen.
