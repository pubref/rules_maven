package(default_visibility = ["//visibility:public"])

android_library(
    name = "my_lib",
    srcs = [
        "java/example/activity/MyActivity.java",
    ],
    resource_files = glob(["res/**/*"]),
    custom_package = "example.activity",
    manifest = "AndroidManifest.xml",
)

android_binary(
    name = "my_app",
    deps = [
        ":my_lib",
    ],
    multidex = "native",
    dex_shards = 4,
    custom_package = "example.activity",
    manifest = "AndroidManifest.xml",
    visibility = [
        "//visibility:public"
    ]
)
