# This script url2json.sh is the heart behind gradle dependency lock generation
{ stdenv, fetchurl }:
stdenv.mkDerivation {
  name = "url2json";
  phases = [ "buildPhase" ];
  src = fetchurl {
    url = "https://github.com/status-im/status-mobile/raw/2df7a7cf6d46c8d1add73b8965ce8b04e6f7d014/nix/deps/gradle/url2json.sh";
    hash = "sha256-McEyQPvofpMYv7mvX/7m/eRNYxJOUkm98foSYmYOyE4=";
    executable = true;
  };
  buildPhase = ''
    mkdir -p $out/bin; cd $out/bin
    cp $src url2json.sh
    chmod +w url2json.sh; patch -p1 < ${./url2json-fix-printing.patch}; chmod -w url2json.sh
    mv url2json.sh url2json
  '';
  meta.mainProgram = "url2json";
}
