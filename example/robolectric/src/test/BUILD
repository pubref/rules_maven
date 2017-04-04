java_test(
    name = "my_activity_test",
    srcs = [
        "java/example/activity/MyActivityTest.java",
    ],
    deps = [
        "@robolectric//:default",
        "@junit4//:default",
        "//src/main:libmy_lib.jar",
        #"//src/main:my_lib_resources.jar", # Contains the generated R.class, but not exposed by the android_library rule.
    ],
    visibility = [
        "//visibility:public"
    ]
)
