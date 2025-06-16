{
  description = "A flake to build nix-on-droid apk";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # gradle2nix only for buildGradlePackage
    # lockFile generation in nix/deps-scripts.nix
    gradle2nix.url = "github:tadfisher/gradle2nix/v2";
    # android-nixpkgs.url = "github:tadfisher/android-nixpkgs/stable";
    # android-nixpkgs.inputs.nixpkgs.follows = "nixpkgs";
    # can't get it to work with ndk, hit https://github.com/tadfisher/android-nixpkgs/issues/113
  };

  outputs =
    {
      self,
      nixpkgs,
      gradle2nix,
      ...
    }:
    let
      system = "x86_64-linux"; # TODO iter attrs over [ aarch64-darwin x86_64-darwin x86_64-linux]
      inherit (nixpkgs) lib;
      pkgs = import nixpkgs {
        inherit system;
        config.android_sdk.accept_license = true;
        config.allowUnfree = true;
      };
      buildToolsVersion = "30.0.3";
      aapt2buildToolsVersion = "33.0.2"; # fixes ERROR:AAPT: unknown option '--source-path'.
      android = pkgs.androidenv.composeAndroidPackages {
        includeNDK = true;
        ndkVersions = [
          "22.1.7171670"
          "23.1.7779620"
          # "21.1.6352462" # jitpack_ndk_version ?
        ];
        platformVersions = [
          "28"
          "30"
        ];
        buildToolsVersions = [
          buildToolsVersion
          aapt2buildToolsVersion
        ];
        includeEmulator = false;
        includeSystemImages = false;
      };
      jdk = pkgs.jdk11_headless;
      # gradle = pkgs.gradle_7.unwrapped;
      gradle = pkgs.callPackage (pkgs.gradleGen {
        version = "7.5";
        hash = "sha256-y4fyIsVYW9RoOK1Nt4RjpcXz0zbl4rmNx8DFhlJzUcI=";
        defaultJava = jdk;
      }) { };

      # https://github.com/Cliquets/scrcpy/blob/main/flake.nix
      extraGradleFlags = [
        "--offline"
        "--no-daemon"
        # override aapt2
        "-Dorg.gradle.project.android.aapt2FromMavenOverride=${android.androidsdk}/libexec/android-sdk/build-tools/${aapt2buildToolsVersion}/aapt2"
      ];
      overrideGradleFlags =
        drv:
        drv.overrideAttrs (prev: {
          gradleFlags = (prev.gradleFlags or [ ]) ++ extraGradleFlags;
        });
      buildGradlePackage =
        args: overrideGradleFlags (gradle2nix.builders.${system}.buildGradlePackage args);

      # TODO use newScope or overlays like status-im app does
      scripts = pkgs.callPackage ./nix/deps-scripts.nix {
        inherit gradle;
        go-maven-resolver = self.packages.${system}.go-maven-resolver;
      };
    in
    {
      packages.${system} = {
        default = buildGradlePackage {
          pname = "nix-on-droid-app";
          version = "0.118.3";
          src = lib.cleanSource ./.;
          lockFile = ./nix/gradle.lock;

          inherit gradle;
          buildJdk = jdk;

          ANDROID_SDK_ROOT = "${android.androidsdk}/libexec/android-sdk";
          ANDROID_NDK_ROOT = "${android.androidsdk}/ndk-bundle";
          nativeBuildInputs = [ android.androidsdk ];
          gradleBuildFlags = [ "assembleRelease" ];

          installPhase = ''
            mkdir $out
            cp -r app/build/outputs/* $out
          '';
        };
        go-maven-resolver = pkgs.callPackage ./nix/go-maven-resolver.nix { };
      };
      devShells.${system}.default = pkgs.mkShellNoCC {
        JAVA_HOME = jdk.home;
        ANDROID_SDK_ROOT = "${android.androidsdk}/libexec/android-sdk";
        ANDROID_NDK_ROOT = "${android.androidsdk}/ndk-bundle";
        packages = [
          jdk
          gradle
          android.androidsdk
          android.platform-tools

          scripts.resolve-gradle-deps
          scripts.regen-lock
          scripts.build-apk

          scripts.url2json
          scripts.gen-deps-lock
          self.packages.${system}.go-maven-resolver
        ];
      };
    };
}
