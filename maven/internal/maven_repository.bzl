load("//maven:internal/require_toolchain.bzl", "require_toolchain")

_BUILD_GRADLE = """
apply plugin: 'java'
configurations.all {
  resolutionStrategy.failOnVersionConflict()
}
repositories {
    mavenCentral()
}
dependencies {
   %s
}
"""

def _flatten(name):
    """Convert characters {dot, dash} to underscore.
    Args:
      name: string - The string to replace.
    Returns: string - The replaced string.
    """
    return name.replace(".", "_").replace("-", "_")


def _format_ws_name(group, name):
    """Create the workspace name
    Args:
      group: string - The maven group.
      name: string - The maven artifact name.
    Returns: string - the workspace name.
    """
    return "%s_%s" % (_flatten(group), _flatten(name));


def _create_artifact_from_coordinate(coord):
    """Create an dict representation of the coordinate.
    Args:
      coord: string - A colon-separated string. Under normal cases,
      there should be 3 parts.
    Returns: !dict<string,string> - {ws_name: string,
                                     group:string,
                                     group_name: string,
                                     version: string,
                                     coordinate: string,
                                     sha1: None}
    """
    parts = coord.split(":")
    if  len(parts) != 3:
        fail("Should take the form 'GROUP:NAME:VERSION': " + coord, "deps")
    group = parts[0]
    name = parts[1]
    version = parts[2]
    coordinate = ":".join([group, name, version])
    ws_name = _format_ws_name(group, name)

    return {
        "ws_name": ws_name,
        "group": group,
        "name": name,
        "group_name": group + ':' + name,
        "version": version,
        "coordinate": coordinate,
        "sha1": None,
    }


def _create_artifact_from_transitive_dependency(dep):
    """Create an dict representation of the dependency.
    Args:
      dep: string - A colon-separated string.  There must be a least 4 parts. The first part is the
           sha1 hash value OR the special token 'omit' (case insensitive).
    Returns: !dict<string,string>
    """

    # Split the dependency string into compoennt parts.  There should
    # always be 4 parts.
    parts = dep.split(":")
    if len(parts) < 4:
        fail("Transitive dependency entries must be in a colon-delimited form having exactly 4 fields: HASH:GROUP:NAME:VERSION.  HASH can be an sha1 value or the special token 'OMIT'")

    # Pop the hash off the dependency.  Remainder is the maven
    # coordinate.
    hash = parts.pop(0)

    # Go ahead and build the artifact dict now so we can add fields to
    # it shortly.
    artifact = _create_artifact_from_coordinate(":".join(parts))

    # Examine the hash.  If it looks like a sha1, great.  Otherwise
    # check it against the list of special tokens (currently only 1:
    # omit)
    if len(hash) == 40:
        artifact["sha1"] = hash
    else:
        if hash.lower() == 'omit':
            artifact["omit"] = True
        else:
            fail("Bad sha1 value %r in %r" % (hash, dep), "transitive_deps")

    # Done
    return artifact


def _get_artifact_sha1(rtx, artifact):
    """Fetch and read the expected sha1 value for an artifact.
    Args:
      rtx: !repository_ctx
      artifact: !dict<string,string>
    Returns: string
    """

    # Prepare the path.  TODO: is this repeatable across multiple
    # maven repositories?
    group = artifact["group"].replace(".", "/")
    name = artifact["name"]
    version = artifact["version"]
    ws_name = artifact["ws_name"]
    output_file = ws_name + ".jar.sha1"

    # TODO: make this configurable.
    path = "https://repo1.maven.org/maven2/{group}/{name}/{version}/{name}-{version}.jar.sha1".format(
        group = group,
        name = name,
        version = version,
    )

    # Download the file - I guess bazel just bails on exception here,
    # can't catch it.
    rtx.download(path, output_file)

    # Print the contents of the file and store it in the 'sha1'
    # fields.
    result = rtx.execute(["cat", output_file])
    if result.return_code:
        fail("Unable to cat sha1 value at %s" % output_file)
    sha1 = result.stdout.strip()
    # Some files have this form:
    # 6975da39a7040257bd51d21a231b76c915872d38  /home/maven/repository-staging/to-ibiblio/maven2/javax/inject/javax.inject/1/javax.inject-1.jar
    if len(sha1) > 40:
        # Some files have the form
        sha1 = sha1.split(" ")[0]
    return sha1


def _parse_gradle_dependencies(rtx, transitive_artifacts, configurations, out):
    """Parse the output of 'gradle dependencies'
    Args:
      rtx: !repository_ctx
      transitive_artifacts: !dict<string,!dict<string,string>>
      configurations: !list<string> - the list of acceptable configuration names.
      out: string (to be processed as a list of lines)

    Returns: !dict<string,!dict<string,string>> - a dict, keyed by
    config name, value is a set of artifacts for that configuration.
    """
    configs = {} # return value
    section = None # current section name

    lines = out.splitlines()
    for line in lines:
        #print("LINE: " + line)
        # Look for lines like 'testCompile - Dependencies for...'
        parts = line.partition(" - ")
        # If we match a known config name, start a new section.
        if parts[0] in configurations:
            section = parts[0]
            configs[section] = {}
        else:
            # Bail now if gradle not able to fetch the dependency.
            if line.endswith("FAILED"):
                fail("Unable to fetch dependency: " + line)
            # Look for lines like ' | +--- org.ow2.asm:asm:5.0.1'.
            # (the triple-dash-space appears constant).
            parts = line.partition("--- ")
            # artifact set must be defined, and the line must start with a artifact marker.
            # +--- org.eclipse.jetty.websocket:websocket-servlet:9.3.10.v20160621
            # |    \--- org.eclipse.jetty:jetty-util:9.3.10.v20160621
            if parts[0].endswith("+") or parts[0].endswith("\\"):
                artifact = parts[2]
                # This means the subtree is repeated, so no need to store it again.
                # +--- org.eclipse.jetty:jetty-jndi:9.3.10.v20160621 (*)
                if not artifact.endswith(" (*)"):
                    # If the artifact is not a root, it does not need
                    # to be listed in the deps attribute.
                    if len(parts[0]) > 1 and artifact in rtx.attr.deps:
                        fail("%r is a transitive dependency and does not need to be explicitly declared in deps" % (artifact), "deps")
                    artifact = _create_artifact_from_coordinate(artifact)
                    ws_name = artifact["ws_name"]
                    # Do we have a listing for this one in the transitive set?
                    transitive_artifact = transitive_artifacts.get(ws_name)
                    # If there is no current listing, store it.
                    if not transitive_artifact:
                        transitive_artifact = artifact
                        transitive_artifacts[ws_name] = artifact
                        # Mark this as new to trigger printing if the
                        # final maven_dependency rule
                        transitive_artifact["new"] = True
                    if not transitive_artifact.get("omit"):
                        if not transitive_artifact.get("sha1"):
                            transitive_artifact["sha1"] = _get_artifact_sha1(rtx,
                                                                             transitive_artifact)
                        configs[section][ws_name] = transitive_artifact
                    # Mark this as seen to be able detect extraneous elements in the transitive_deps attribute.
                    transitive_artifact["seen"] = True

                #else: print("skipping line: " + line)
            #else: print("skipping line parts = %r" % (parts))

    #print("configs: %r" % configs)
    return configs


def _format_build_file(configs):
    """Generate the BUILD file content.
    Args:
      configs: !dict<string,!dict<string,!Artifact>>
    Returns: string
    """
    lines = []
    lines.append("# AUTO_GENERATED, DO NOT EDIT")
    for name, artifacts in configs.items():
        lines += _format_java_library(name, artifacts)
    return "\n".join(lines)


def _format_java_library(name, artifacts):
    """Format a java_library_rule.
    Args:
      name: string - the workspace name.
      artifacts: !dict<string,!Artifact>
    Returns: !list<string>
    """
    lines = []
    lines.append("java_library(")
    lines.append("  name = '%s'," % name)
    lines.append("  exports = [")
    for ws_name in artifacts.keys():
        lines.append("    '@%s//jar'," % ws_name)
    lines.append("  ],")
    lines.append("  visibility = ['//visibility:public'],")
    lines.append(")")
    return lines


def _format_rules_file(rule_name, configs, all_artifacts):
    """Generate the rules.bzl file content.
    Args:
      rule_name: string - The name of the rule (rtx.name)
      configs: !dict<string,!dict<string,!Artifact>>
      all_artifacts: !dict<string,!Artifact>
    Returns: string
    """
    lines = []
    lines.append("# AUTO_GENERATED, DO NOT EDIT")
    lines.append("load('@org_pubref_require_toolchain//:require.bzl', 'require')")
    lines.append("DEPS = {")
    for ws_name, artifact in all_artifacts.items():
        lines += _format_maven_jar(ws_name, artifact)
    lines.append("}")
    for name, artifacts in configs.items():
        lines += _format_config_def(rule_name + "_" + name, artifacts)
    return "\n".join(lines)


def _format_maven_jar(ws_name, artifact):
    """Format a maven_jar rule (in require form).
    Args:
      name: string - the workspace name.
      artifacts: !dict<string,!Artifact>
    Returns: !list<string>
    """
    lines = []
    lines.append("  '%s': {" % ws_name)
    lines.append("    'rule': 'maven_jar',")
    lines.append("    'artifact': '%s'," % artifact["coordinate"])
    lines.append("    'sha1': '%s'," % artifact["sha1"])
    lines.append("  },")
    return lines


def _format_config_def(name, artifacts):
    """Format a macro function for a given configuration.
    Args:
      name: string - the configuration name.
      artifacts: !dict<string,!Artifact>
    Returns: !list<string>
    """
    lines = []
    lines.append("def %s(deps = DEPS, excludes = [], overrides = {}):" % name)
    lines.append("  require([")
    for ws_name, artifact in artifacts.items():
        lines.append("    '%s'," % ws_name)
    lines.append("  ], deps = deps, excludes = excludes, overrides = overrides)")
    return lines


def _format_maven_repository(rtx, configs, all_artifacts):
    """Format a maven_repository rule, for copy-paste back into the WORKSPACE.
    Args:
      rtx: !repository_ctx
      configs: !dict<string,!dict<string,!Artifact>>
      all_artifacts: !dict<string,!Artifact>
    Returns: !list<string>
    """
    lines = []
    lines.append("maven_repository(")
    lines.append("    name = '%s'," % rtx.name)
    lines.append("    deps = [")
    for coord in rtx.attr.deps:
        lines.append("        '%s'," % coord)
    lines.append("    ],")
    lines.append("    transitive_deps = [")
    for ws_name, artifact in all_artifacts.items():
        lines.append("        '%s:%s'," % (artifact["sha1"], artifact["coordinate"]))
    lines.append("    ],")
    lines.append(")")
    return lines


def _execute(rtx, cmds):
    """Execute a command and fail if return code.
    Args:
      rtx: !repository_ctx
      cmds: !list<string>
    Returns: struct value from the rtx.execute method.
    """
    result = rtx.execute(cmds)
    if result.return_code:
        fail(" ".join(cmds) + "failed: %s" %(result.stderr))
    return result


def _create_artifact_cache_from_transitive_deps(entries):
    """Build a dict of artifacts keyed by the workspace name.
    Args:
      entries: !list<string>
    Return: !dict<string,!Artifact>
    """
    cache = {}
    for entry in entries:
        artifact = _create_artifact_from_transitive_dependency(entry)
        cache[artifact["ws_name"]] = artifact
    return cache


def _maven_repository_impl(rtx):
    java = rtx.which("java")
    launcher_jar = rtx.path(rtx.attr._gradle_launcher_jar)

    # Generate a set of artifacts given by the transitive_deps
    # attribute, if one is present.  This set will be used to resolve
    # conflicts and/or omit desired artifacts.
    transitive_artifacts = _create_artifact_cache_from_transitive_deps(rtx.attr.transitive_deps)

    # Write a build.gradle file where our exection scope will be.
    gdeps = ["  compile('%s')" % a for a in rtx.attr.deps]
    rtx.file("build.gradle", _BUILD_GRADLE % "\n".join(gdeps));

    # Execute the gradle dependencies task
    result = _execute(rtx, [java, '-jar', launcher_jar, 'dependencies']);
    #print("result: %s" % result.stdout)

    # Generate a set of configurations based on the output of the command.
    configs = _parse_gradle_dependencies(rtx,
                                         transitive_artifacts,
                                         rtx.attr.configurations,
                                         result.stdout)

    # If there are any new entries in the transitive_artifacts dict,
    # print the rule so it can be copy-pasted over.
    print_rule = False
    for artifact in transitive_artifacts.values():
        if not artifact.get("seen"):
            fail("%r was listed in transitive_deps, but it shouldn't be (please remove it)." % artifact["coordinate"], "transitive_deps")
        if artifact.get("new"):
            print_rule = True

    if print_rule:
        lines = _format_maven_repository(rtx, configs, transitive_artifacts)
        print("\n# CLOSED-FORM RULE:\n# You can copy this to your WORKSPACE To suppress this message. \n%s\n" % "\n".join(lines))

    rtx.file("BUILD", _format_build_file(configs));
    rtx.file("rules.bzl", _format_rules_file(rtx.name, configs, transitive_artifacts));


maven_repository = repository_rule(
    implementation = _maven_repository_impl,
    attrs = {
        "deps": attr.string_list(
            mandatory = True,
        ),
        "transitive_deps": attr.string_list(
        ),
        "_java": attr.label(
            default = Label("//external:java"),
            executable = True,
            cfg = "host",
        ),
        "_gradle_launcher_jar": attr.label(
            default = Label("@gradle_distribution//:lib/gradle-launcher-3.2.1.jar"),
            executable = True,
            cfg = "host",
        ),
        "configurations": attr.string_list(
            default = ["compile", "default", "runtime",
                       "compileOnly", "compileClasspath"],
        ),
    }
)
