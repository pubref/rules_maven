_BUILD_GRADLE = """
apply plugin: 'java'
repositories {
    jcenter()
}
dependencies {
   %s
}
"""

def _parse_configuration(configurations, out):
    lines = out.splitlines()
    configs = {} # map of configs
    section = None # current section name
    for line in lines:
        parts = line.partition(" - ")
        if parts[0] in configurations:
            section = parts[0]
            configs[section] = set()
        else:
            if line.endswith("FAILED"):
                fail("Unable to fetch dependency: " + line)
            parts = line.partition("--- ")
            # artifact set must be defined, and the line must start with a artifact marker.
            if parts[0].endswith("+") or parts[0].endswith("\\\\"):
                artifact = parts[2]
                if not artifact.endswith(" (*)"):
                    configs[section] = configs[section] | set([artifact])
    #print("configs: %r" % configs)
    return configs

def _format_build_file(configs):
    lines = []
    lines.append("# AUTO_GENERATED, DO NOT EDIT")
    for name, artifacts in configs.items():
        lines += _format_java_library(name, artifacts)
    return "\n".join(lines)

def _format_java_library(name, artifacts):
    lines = []
    lines.append("java_library(")
    lines.append("  name = '%s'," % name)
    lines.append("  exports = [")
    for a in artifacts:
        lines.append("    '@%s//jar'," % _format_workspace_name(a))
    lines.append("  ],")
    lines.append("  visibility = ['//visibility:public'],")
    lines.append(")")
    return lines

def _format_rules_file(configs):
    # Make a master list of artifacts
    all_artifacts = set()
    for name, artifacts in configs.items():
        all_artifacts = all_artifacts.union(artifacts)

    lines = []
    lines.append("# AUTO_GENERATED, DO NOT EDIT")
    lines.append("load('@org_pubref_rules_require//require:rules.bzl', 'require')")
    lines.append("DEPS = {")
    for artifact in all_artifacts:
        lines += _format_maven_jar(artifact)
    lines.append("}")

    for name, artifacts in configs.items():
        lines += _format_config_def(name, artifacts)

    return "\n".join(lines)

def _format_maven_jar(artifact):
    lines = []
    lines.append("  '%s': {" % _format_workspace_name(artifact))
    lines.append("    'rule': 'maven_jar',")
    lines.append("    'artifact': '%s'," % artifact)
    lines.append("  },")
    return lines

def _format_config_def(name, artifacts):
    lines = []
    lines.append("def %s(deps = DEPS, excludes = [], overrides = {}):" % name)
    lines.append("  require([")
    for a in artifacts:
        lines.append("    '%s'," % _format_workspace_name(a))
    lines.append("  ], deps = deps, excludes = excludes, overrides = overrides)")
    return lines

def _flatten(name):
    return name.replace(".", "_").replace("-", "_")

def _format_workspace_name(artifact):
    parts = artifact.split(":")
    return "%s_%s" % (_flatten(parts[0]), _flatten(parts[1]));

def _execute(ctx, cmds):
    result = ctx.execute(cmds)
    if result.return_code:
        fail(" ".join(cmds) + "failed: %s" %(result.stderr))
    return result

def _maven_dependencies_impl(ctx):
    java = ctx.which("java")
    launcher_jar = ctx.path(ctx.attr._gradle_launcher_jar)

    gdeps = ["compile('%s')" % a for a in ctx.attr.artifacts]
    ctx.file("build.gradle", _BUILD_GRADLE % "\n".join(gdeps));

    args = [
        java, '-jar', launcher_jar, 'dependencies',
    ]
    result = _execute(ctx, args);

    print("result: %s" % result.stdout)
    configs = _parse_configuration(ctx.attr.configurations, result.stdout)
    ctx.file("BUILD", _format_build_file(configs));
    ctx.file("rules.bzl", _format_rules_file(configs));

maven_dependencies = repository_rule(
    implementation = _maven_dependencies_impl,
    attrs = {
        "artifacts": attr.string_list(
            mandatory = True,
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
            mandatory = True,
            default = ["compile", "default", "runtime",
                       "compileOnly", "compileClasspath"],
            }
        ),
    }
)
