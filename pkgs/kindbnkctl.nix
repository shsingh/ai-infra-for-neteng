{ lib
, stdenv
, fetchurl
, writeShellScriptBin
}:

let
  version = "2.3.0-11";
  isAmd64Linux = stdenv.hostPlatform.isLinux && stdenv.hostPlatform.isx86_64;
in
if isAmd64Linux then
  stdenv.mkDerivation {
    pname = "kindbnkctl";
    inherit version;

    src = fetchurl {
      url = "https://github.com/mwiget/kindbnkctl/releases/download/v${version}/kindbnkctl_${version}_linux_amd64.tar.gz";
      sha256 = "25502cba690db7748087ed3314b6c3c3fd0ff8a12a3d714267d597fc5c723f3a";
    };

    sourceRoot = ".";

    installPhase = ''
      runHook preInstall
      install -m 755 -D kindbnkctl $out/bin/kindbnkctl
      runHook postInstall
    '';

    meta = with lib; {
      description = "CLI tool to deploy BIG-IP Next for Kubernetes on kind clusters";
      homepage = "https://github.com/mwiget/kindbnkctl";
      license = licenses.asl20;
      platforms = [ "x86_64-linux" ];
      mainProgram = "kindbnkctl";
    };
  }
else
  writeShellScriptBin "kindbnkctl" ''
    echo "ERROR: kindbnkctl is only available for linux/amd64 (current: ${stdenv.hostPlatform.system})" >&2
    echo "Per AGENTS.md Rule 6: F5 container images and kindbnkctl are x86_64 only." >&2
    exit 1
  ''
