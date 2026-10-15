{
  description = "AI Infrastructure for Network Engineers — BIG-IP Next for Kubernetes 2.4 edition";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
          };
        };

        kindbnkctl = pkgs.callPackage ./pkgs/kindbnkctl.nix { };
        courseLibs = pkgs.callPackage ./pkgs/course-libs.nix { };

        doctor = pkgs.callPackage ./apps/doctor.nix {
          inherit courseLibs;
        };

        bootstrap = pkgs.callPackage ./apps/bootstrap.nix {
          inherit courseLibs kindbnkctl;
        };

        teardown = pkgs.callPackage ./apps/teardown.nix {
          inherit courseLibs kindbnkctl;
        };

        devShell = pkgs.callPackage ./devShells/default.nix {
          inherit kindbnkctl courseLibs;
        };
      in
      {
        packages = {
          inherit kindbnkctl;
          course-libs = courseLibs;
          default = kindbnkctl;
        };

        apps = {
          doctor = flake-utils.lib.mkApp {
            drv = doctor;
            name = "doctor";
          };
          bootstrap = flake-utils.lib.mkApp {
            drv = bootstrap;
            name = "bootstrap";
          };
          teardown = flake-utils.lib.mkApp {
            drv = teardown;
            name = "teardown";
          };
          default = flake-utils.lib.mkApp {
            drv = doctor;
            name = "doctor";
          };
        };

        devShells = {
          default = devShell;
        };

        checks = {
          inherit kindbnkctl courseLibs doctor bootstrap teardown;
          eval-check = pkgs.runCommand "eval-check" { } ''
            echo "Flake evaluation check passed for ${system}" > $out
          '';
        };
      }
    );
}
