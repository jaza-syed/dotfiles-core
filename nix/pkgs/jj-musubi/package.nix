# The upstream release binary, as nixpkgs does not package jj-musubi.
{
  lib,
  stdenvNoCC,
  fetchurl,
}:
let
  version = "0.47.1";
  targets = {
    aarch64-linux = {
      triple = "aarch64-unknown-linux-musl";
      hash = "sha256-Y4/saNAGQrN1X3CmeLoGnvuEOA2USJE1lMWrh8EuTWY=";
    };
    x86_64-linux = {
      triple = "x86_64-unknown-linux-musl";
      hash = "sha256-eH3FHit/ucvaBPcPRMtNYSlZptx97vhATeZfwFuoGok=";
    };
    aarch64-darwin = {
      triple = "aarch64-apple-darwin";
      hash = "sha256-VHFXgQaIuYJJfpvbP5mJaUrz0sspiVGWTNy29tY/9h4=";
    };
  };
  target = targets.${stdenvNoCC.hostPlatform.system};
in
stdenvNoCC.mkDerivation {
  pname = "jj-musubi";
  inherit version;

  src = fetchurl {
    url = "https://github.com/bos/jj-musubi/releases/download/v${version}/jj-musubi-${version}-${target.triple}.tar.gz";
    inherit (target) hash;
  };

  installPhase = "install -Dm755 musubi $out/bin/musubi";

  meta = {
    description = "Live sync of jj repos across machines";
    homepage = "https://github.com/bos/jj-musubi";
    license = lib.licenses.asl20;
    mainProgram = "musubi";
    platforms = builtins.attrNames targets;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
