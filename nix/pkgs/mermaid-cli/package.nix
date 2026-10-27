# Copied from nixpkgs unstable, since nixos-26.05 has 11.12.0, whose bundled
# mermaid predates the redux themes and the neo look.
{
  buildNpmPackage,
  lib,
  stdenv,
  fetchFromGitHub,
  chromium,
}:
let
  version = "12.0.0";
in
buildNpmPackage {
  pname = "mermaid-cli";
  inherit version;

  src = fetchFromGitHub {
    owner = "mermaid-js";
    repo = "mermaid-cli";
    rev = version;
    hash = "sha256-8CPcwqWz7A91Qyp9fpObv1m7K8H6A0c8UULjj1XlB+c=";
  };

  patches = [
    ./remove-puppeteer-from-dev-deps.patch # https://github.com/mermaid-js/mermaid-cli/issues/830
  ];

  npmDepsHash = "sha256-Y1w7oMGDUU7fNFijbjNbnlhY9nEMSR7ilNC3RnlLMaU=";

  env = {
    PUPPETEER_SKIP_DOWNLOAD = true;
  };

  npmBuildScript = "prepare";

  # nixpkgs has no chromium for darwin, so darwin uses the Chrome cask that
  # nix/darwin/homebrew.nix installs.
  makeWrapperArgs =
    if stdenv.hostPlatform.isDarwin then
      [ "--set PUPPETEER_EXECUTABLE_PATH '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'" ]
    else
      lib.lists.optional (lib.meta.availableOn stdenv.hostPlatform chromium) "--set PUPPETEER_EXECUTABLE_PATH '${lib.getExe chromium}'";

  meta = {
    description = "Generation of diagrams from text in a similar manner as markdown";
    homepage = "https://github.com/mermaid-js/mermaid-cli";
    license = lib.licenses.mit;
    mainProgram = "mmdc";
  };
}
