# `rules_maven` [![Build Status](https://travis-ci.org/pubref/rules_maven.svg?branch=master)](https://travis-ci.org/pubref/rules_maven)

<table><tr>
<td><img src="https://avatars1.githubusercontent.com/u/11684617?v=3&s=200" height="120"/></td>
<td><img src="http://studentaffairs.uci.edu/resources/right-facing-blk-outline.png" height="120"/></td>
</tr><tr>
<td>Rules</td>
<td>Maven</td>
</tr></table>
[Bazel](https://bazel.build) rules for working with transitive maven dependencies.

## Rules

|               Name   |  Description |
| -------------------: | :----------- |
| [maven_repositories](#maven_repositories) |  Load dependencies for this repo. |
| [maven_repository](#maven_repository) | Declare an external workspace that defines transitive dependencies for a set of maven artifacts. |

## Usage

### 1. Add rules_maven to your WORKSPACE

```python
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

Two files are written in `($bazel info output_base)/external/jetty`:

1. `rules.bzl`: this file contains require definitions over the
   transitive closure of the maven jar dependency tree.  A separate
   macro is defined foreach gradle configuration (default: `compile`,
   `runtime`, `compileOnly`, `compileClasspath`, 'testCompile`, and
   `testRuntime`; can be customized via the `configurations`
   attribute).  You'll want to invoke one or more of these macros.

2. `BUILD`: the build file contains a `java_library` rule foreach
   generated configuration. Each rule exports the flattened transitive
   set of dependencies.  You'll use these as dependencies for your
   java rules.

### 3. Load the generated `@jetty//:rules.bzl` in your WORKSPACE and invoke the desired configuration.

> Alias the loaded function into a more specific name within your
> workspace.

```python
load("@jetty//:rules.bzl", jetty_runtime = "runtime")
jetty_runtime()
```

### 4. Depend on the java_library rule for the desired configuration.

```python
java_binary(
  name = "app",
  main_class = "example.App",
  deps = ["@jetty//:runtime"],
)
```

Consult the documentation of `rules_require` for exclusions,
overrides, and dependency replacement options.

### Final WORKSPACE

To further illustrate steps 1-3 are all in the same file.

```python
git_repository(
  name = "org_pubref_rules_maven",
  remote = "https://github.com/pubref/rules_maven",
  commit = HEAD, # replace with latest version
)

load("@org_pubref_rules_maven//maven:rules.bzl", "maven_repositories")
maven_repositories()

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
load("@jetty//:rules.bzl", jetty_runtime = "runtime")
jetty_runtime()
```

# Credits

Depending on a rule that is defined earlier in the workspace is now
possible due to the interleaved loading and analysis phases of bazel.
Previously, this approach would not work.  Thanks Bazel team for
making this happen.

The anteater image is a reference to the O'Reilly book cover.  This image is
actually "Peter", the University of California Irvine
mascot. [**ZOT!**](http://studentaffairs.uci.edu/resources/right-facing-blk-outline.png).
