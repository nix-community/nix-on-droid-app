{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule (finalAttrs: {
  pname = "go-maven-resolver";
  version = "1.1.2-unstable-2025-06-16";

  vendorHash = "sha256-dlqI+onfeo4tTwmHeq8heVKRzLU1gFEQ+4iv+8egN90=";

  src = fetchFromGitHub {
    owner = "status-im";
    repo = "go-maven-resolver";
    rev = "473b36df1d12996fc5fbcb8b7cc4f60c9aa4f8e0";
    hash = "sha256-wYGjOcNnhMU2hwKGNLEAT4CcienKw5CvWieH1wV7bA8=";
  };

  meta = {
    description = "go maven resolver";
    homepage = "https://github.com/status-im/go-maven-resolver";
    license = lib.licenses.mit;
    mainProgram = "go-maven-resolver";
  };
})
