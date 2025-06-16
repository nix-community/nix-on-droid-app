{
  bash,
  coreutils,
  curl,
  jq,
  htmlq,
  gawk,
  gitMinimal,
  gnused,
  gnugrep,
  gradle,
  fetchurl,
  parallel,
  moreutils,
  writeShellApplication,
  go-maven-resolver,
  callPackage,
}:
let
  url2json = callPackage ./url2json.nix { };
  resolve-gradle-deps = writeShellApplication {
    name = "resolve-gradle-deps";
    runtimeInputs = [
      gradle
      gitMinimal
    ];
    inheritPath = false;
    text = ''
      pushd "$(git rev-parse --show-toplevel)" >/dev/null || exit 1
      gradle -I nix/init.gradle \
        --no-daemon --dependency-verification=off \
        --no-configuration-cache --no-configure-on-demand \
        :ForceDependencyResolutionPlugin_resolveAllDependencies >/dev/null 2>&1 || exit 1
      popd >/dev/null || exit 1
    '';
    meta.description = "Generates the full dependency report from current project";
  };
  gen-deps-lock = writeShellApplication {
    name = "gen-deps-lock";
    bashOptions = [ ]; # TODO decide what these should be
    runtimeInputs = [
      gawk
      gitMinimal
      gnused
      gnugrep
      # order matters, parallel first, then moreutils
      parallel
      moreutils # sponge
      go-maven-resolver

      url2json
      bash
      jq
      htmlq
      curl
      coreutils
    ];
    text = ''
      pushd "$(git rev-parse --show-toplevel)" >/dev/null || exit 1

      out=''${2:-nix/gradle.lock}

      # trim/format input file properly
      deps_list="$(grep . "$1" | awk '{$1=$1};1')"

      echo "[" >"$out"

      # note: moreutils parallel doesn't work here
      echo -en "$deps_list" | go-maven-resolver | \
        parallel --will-cite --keep-order --jobs 4 url2json >>"$out"

      # convert to gradle2nix lock format
      grep . "$out" | sed '$s/,$/\n]/' | jq -r 'map(. as $root | {
            (.path | split("/") | (.[0:-2] | join(".")) + ":" + .[-2] + ":" + .[-1]): (.files | to_entries | map({
                (.key): {
                    url: ($root.repo + "/" + $root.path + "/" + .key),
                    hash: .value.sha256
                }
            }) | add)
        }) | add' | jq -S . | sponge "$out"

      popd >/dev/null || exit 1
    '';
    inheritPath = true; # url2json needs nix
    meta.description = "script to help create the gradle.lock file";
  };
  regen-lock = writeShellApplication {
    name = "regen-lock";
    runtimeInputs = [
      gen-deps-lock
      gitMinimal
      coreutils # cat
    ];
    text = ''
      set -x
      pushd "$(git rev-parse --show-toplevel)" >/dev/null || exit 1

      gen-deps-lock <(
          # missing deps from build report
          #  https://github.com/status-im/status-mobile/blob/674261c7e2808b918e85428073768827ecfc836d/nix/deps/gradle/deps_hack.sh#L29C1-L29C148
          #  https://github.com/googlesamples/android-custom-lint-rules/blob/be672cd747ecf13844918e1afccadb935f856a72/docs/api-guide/example.md.html#L112-L129

          #  lint-gradle version should be gradle version + 23.0.0, as of now 7.4.2 + 23.0.0
          #   httpclient version can be determined by removing it and running build-apk
          echo -en '
              com.android.tools.lint:lint-gradle:30.4.2
              org.apache.httpcomponents:httpclient:4.5.6
          '
          cat build/reports/dependency-graph-snapshots/dependency-list.txt
      )
      popd >/dev/null || exit 1
    '';
    inheritPath = true; # gen-deps-lock needs path
    meta.description = "Generates the gradle.lock file";
  };
  build-apk = writeShellApplication {
    name = "build-apk";
    runtimeInputs = [
      resolve-gradle-deps
      regen-lock
    ];
    text = # bash
      ''
        # generate full dependency report
        resolve-gradle-deps

        # generate gradle.lock
        regen-lock

        # build apk
        nix build -L
      '';
    inheritPath = true; # need nix, regen-lock needs path
    meta.description = "Re-create gradle.lock and build the apk";
  };
in
{
  inherit
    build-apk
    resolve-gradle-deps
    regen-lock
    gen-deps-lock
    url2json
    ;
}
