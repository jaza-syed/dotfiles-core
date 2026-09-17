# Mermaid to terminal text, shelled out to by the nvim config.diagrams module.
{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage rec {
  pname = "mmdflux";
  version = "2.6.1";

  src = fetchFromGitHub {
    owner = "kevinswiber";
    repo = "mmdflux";
    rev = "mmdflux-v${version}";
    hash = "sha256-w9eqGBylkMar0e/yvZg9MoeHt2NZXJaK24EgIH7Hn4Q=";
  };

  cargoHash = "sha256-AOmClWSfrh6Hu/7UuGht99d24NOlIedfhuyaaprfOZ8=";

  meta = {
    description = "Render Mermaid diagrams as terminal text, SVG and MMDS JSON";
    homepage = "https://github.com/kevinswiber/mmdflux";
    license = lib.licenses.asl20;
    mainProgram = "mmdflux";
  };
}
