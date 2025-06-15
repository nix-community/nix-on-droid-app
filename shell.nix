{
  sources ? import ./npins,
  lib ? pkgs.lib,
  pkgs ? import sources.nixpkgs {
    config.android_sdk.accept_license = true;
    config.allowUnfreePredicate =
      pkg:
      builtins.elem (lib.getName pkg) [
        "android-sdk-platform-tools"
        "android-sdk-cmdline-tools"
        "android-sdk-build-tools"
        "android-sdk-platforms"
        "android-sdk-tools"

        "android-sdk-ndk"
        "android-sdk-ndk-bundle"
      ];
  },
}:
let
  # pkgs.androidenv.androidPkgs.androidsdk pulls in lots of toolchains, slim it down
  android = pkgs.androidenv.composeAndroidPackages {
    includeNDK = true;
    ndkVersions = [
      "22.1.7171670"
      "23.1.7779620"
    ];
    platformVersions = [
      "28"
      "30"
    ];
    buildToolsVersions = [ "30.0.3" ];
    includeEmulator = false;
    includeSystemImages = false;
  };
  jdk = pkgs.jdk11_headless;

  JAVA_HOME = jdk;
  ANDROID_SDK_ROOT = "${android.androidsdk}/libexec/android-sdk";
  ANDROID_NDK_ROOT = "${ANDROID_SDK_ROOT}/ndk-bundle";
in
pkgs.mkShellNoCC {
  inherit JAVA_HOME;
  inherit ANDROID_SDK_ROOT;
  inherit ANDROID_NDK_ROOT;
  packages = [
    jdk
    android.platform-tools
    android.androidsdk
  ];
}
