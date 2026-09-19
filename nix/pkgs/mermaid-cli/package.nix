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
  version = "11.17.0";
in
buildNpmPackage {
  pname = "mermaid-cli";
  inherit version;

  src = fetchFromGitHub {
    owner = "mermaid-js";
    repo = "mermaid-cli";
    rev = version;
    hash = "sha256-Dujs0HNHVWOWlOhPkbAzooWrUqR1kNOdPUfe2f7rVLo=";
  };

  patches = [
    ./remove-puppeteer-from-dev-deps.patch # https://github.com/mermaid-js/mermaid-cli/issues/830
    # 11.17.0 pins mermaid ^11.14.0, so the lockfile is regenerated with
    # mermaid 12 and the three companion packages that peer on it.
    ./mermaid-12.patch
  ];

  npmDepsHash = "sha256-SSdHBaKSxPl03oAYMTP5UWvprM0eMgN09GDOjo5LpvM=";

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
