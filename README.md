# `rules_maven` [![Build Status](https://travis-ci.org/pubref/rules_maven.svg?branch=master)](https://travis-ci.org/pubref/rules_maven)

<table><tr>
<td><img src="https://github.com/bazelbuild.png" height="120"/></td>
<td><img src="https://github.com/gradle.png" height="120"/></td>
</tr><tr>
<td>Rules</td>
<td>Maven</td>
</tr></table>

[Bazel](https://bazel.build) rules for working with transitive maven dependencies.

> The word 'maven' here refers to 'maven artifacts', not the tool 'mvn'.  This
> repo utilizes gradle to assist with transitive dependency management, hence
> the logo reference. 

## Rules

|               Name   |  Description |
| -------------------: | :----------- |
| [maven_repositories](#maven_repositories) |  Load dependencies for this repo. |
| [maven_repository](#maven_repository) | Declare an external workspace that defines transitive dependencies for a set of maven artifacts. |

**Status**: experimental, but actively in use for other internal projects.

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

### 2a. Define an initial maven_repository rule naming the root artifact(s)

```python
load("@org_pubref_rules_maven//maven:rules.bzl", "maven_repository")

maven_repository(
  name = "guice",
  deps = [
    'com.google.inject:guice:4.1.0',
  ],
)
```

Given this initial repository rule defintion, `rules_maven` will:

1. write a `build.gradle` file,

1. install `gradle` as it's own internal dependency (first time only;
   does not interfere with any other gradle you might have installed).

1. call `gradle dependencies` and parse the output,

1. fetch the expected sha1 values for named artifacts,

1. write a `@guice//:rules.bzl` file having the requisite `maven_jar`
   rules (organized by configuration),

1. write a `@guice//:BUILD` file with the requisite `java_library`
   that bundle/export dependencies (one per configuration).

1. print out a formatted `maven_repository` *"hermetic-form"* rule with
   all the transitive dependencies and their sha1 values explicitly named
   (can be disabled via the `hermetic = False` attribute)

### 2b. Copy and paste the closed-form back into your WORKSPACE.

`rules_maven` will regurgitate a so-called *closed-form*
`maven_repository` rule enumerating the transitive dependencies and
their sha1 values in the `transitive_deps` attribute.  Assuming you
trust the data, copy and paste this back into your `WORKSPACE`.

```python
maven_repository(
  name = 'guice',
  deps = [
    'com.google.inject:guice:4.1.0',
  ],
  transitive_deps = [
    '0235ba8b489512805ac13a8f9ea77a1ca5ebe3e8:aopalliance:aopalliance:1.0',
    '6ce200f6b23222af3d8abb6b6459e6c44f4bb0e9:com.google.guava:guava:19.0',
    'eeb69005da379a10071aa4948c48d89250febb07:com.google.inject:guice:4.1.0',
    '6975da39a7040257bd51d21a231b76c915872d38:javax.inject:javax.inject:1',
  ],
)
```

Once the `transitive_deps` is stable (all transitive deps and their correct
sha1 values are listed), `rules_maven` will be silent.

> Note: make sure you leave out the artifact ID type, `rules_maven`
> will get confused about it.  For example, don't say
> `com.google.inject:guice:jar:4.1.0` (leave out the `:jar`
> substring).

### 3. Load the `@guice//:rules.bzl` file in your WORKSPACE and invoke the desired macro configuration.

The `rules.bzl` file (a generated file) contains macro definitions
that ultimately define `native.maven_jar` rules.  A separate macro is
defined for each *gradle configuration*.  The default configurations
are: `compile`, `runtime`, `compileOnly`, `compileClasspath`,
`testCompile`, and `testRuntime`.  (these can be customized via the
`configurations` attribute).

The name of the macros are the gradle configuration name, prefixed
with the rule name.  In this case there are the following macros (and
several others):

* `guice_compile`: Provide compile-time dependencies.
* `guice_runtime`: Provide runtime-time dependencies.
* ...


```python
load("@guice//:rules.bzl", "guice_compile")
guice_compile()
```

> In this case, both `_compile` and `_runtime` macros provide the same dependencies.

> You can inspect the contents of the generated file via:

```sh
$ cat $(bazel info output_base)/external/guice/rules.bzl
```

### 4. Depend on the java_library rule for the desired configuration.

```python
java_binary(
  name = "app",
  main_class = "example.App",
  deps = ["@guice//:compile"],
)
```

### Final WORKSPACE

To further illustrate steps 1-3 are all in the same file.

```python
git_repository(
  name = "org_pubref_rules_maven",
  remote = "https://github.com/pubref/rules_maven",
  commit = HEAD, # replace with latest version
)
load("@org_pubref_rules_maven//maven:rules.bzl", "maven_repositories", "maven_repository")
maven_repositories()


maven_repository(
  name = 'guice',
  deps = [
    'com.google.inject:guice:4.1.0',
  ],
  transitive_deps = [
    '0235ba8b489512805ac13a8f9ea77a1ca5ebe3e8:aopalliance:aopalliance:1.0',
    '6ce200f6b23222af3d8abb6b6459e6c44f4bb0e9:com.google.guava:guava:19.0',
    'eeb69005da379a10071aa4948c48d89250febb07:com.google.inject:guice:4.1.0',
    '6975da39a7040257bd51d21a231b76c915872d38:javax.inject:javax.inject:1',
  ],
)
load("@guice//:rules.bzl", "guice_compile")
guice_compile()
```


### maven_repository attributes

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `name` | `string` | `None` | The rule name. |
| `deps` | `string_list` | `[]` | List of maven artifacts having the form `NAME:GROUP:VERSION` |
| `gradle_build_file` | `label` | `None` | Use the given `build.gradle` file to name dependencies (rather than generating one based on `deps` |
| `transitive_deps` | `string_list` | `[]` | List of maven artifacts in the transitive set reachable from `deps`.  The have the form `SHA1:NAME:GROUP:VERSION`, and are calculated by rules_maven via a generated `build.gradle` file. |
| `exclude` | `string_list_dict` | `{}` | List of artifacts to exclude, in the form `{ 'NAME:GROUP': ['EXCLUDED_GROUP:EXCLUDED_NAME']` |
| `force` | `string_list` | `[]` | List of artifacts to force, in the form `[ 'NAME:GROUP:VERSION']` |
| `omit` | `string_list` | `[]` | List of patterns to skip.  The pattern must either be a substring of the coordinate  `[ 'NAME:GROUP:VERSION']` or equal to the generated workspace name. |
| `hermetic` | `bool` | `True` | Regurgitate the rule with all transitive deps listed |
| `repositories` | `string_list_dict` | `{}` | A mapping of artifact-id pattern to url (see below) |
| `configurations` | `string_list` | `["compile", "default", "runtime", "compileOnly", "compileClasspath"]` | List of configurations to generate a corresponding rule for. |
| `experimental_disambiguate_maven_jar_workspace_names` | `bool` | `False` | See Note |


> `experimental_disambiguate_maven_jar_workspace_names`: This option
> changes the name of the generated workspace name for maven_jar
> rules.  For example, consider the artifact
> `com.google.guava:guava:20.0`.  The corresponding workspace name
> under default conditions is `com_google_guava_guava`.  If
> `experimental_disambiguate_maven_jar_workspace_names = True`, the
> workspace name includes the version specifier and becomes
> `com_google_guava_guava_20_0`.

Example use of the `repositories` attribute:


```python
# Load commons-imaging from adobe nexus repository.
# Load everything else (junit) from maven central.
maven_repository(
    name = "maven",
    repositories = {
        "https://repo.adobe.com/nexus/content/repositories/public/": [
            "org.apache.commons:commons-imaging",
        ],
    },
    deps = [
        "junit:junit:4.12",
        "org.apache.commons:commons-imaging:1.0-R1534292",
    ],
)
```
