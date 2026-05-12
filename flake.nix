{
  description = "Standalone build of htop";

  nixConfig = {
    extra-substituters = [ "https://unpins.cachix.org" ];
    extra-trusted-public-keys = [ "unpins.cachix.org-1:DDaShjbZ8VvcqxeTcAU3kV9vxZQBlyb7V/uLBHfTynI=" ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    unpins-lib.url = "github:unpins/nix-lib/v1";
  };

  outputs = { self, nixpkgs, unpins-lib }:
    let
      ulib = unpins-lib.lib;

      # htop pulls lm_sensors on Linux. Upstream lm_sensors propagates perl +
      # bash for sensors-detect, which we don't ship. Drop them and remove
      # the helper scripts so they don't end up in the closure.
      lmSensorsOverlay = final: prev: {
        lm_sensors = prev.lm_sensors.overrideAttrs (old: {
          propagatedBuildInputs = prev.lib.filter
            (p: !builtins.elem (p.pname or "") [ "perl" "bash" ])
            (old.propagatedBuildInputs or []);
          postInstall = (old.postInstall or "") + ''
            rm -f $out/bin/sensors-detect $out/bin/sensors-conf-convert
            rm -f $out/sbin/sensors-detect $out/sbin/sensors-conf-convert
          '';
        });
      };

      nixpkgsFor = ulib.forAllNative (system: import nixpkgs {
        inherit system;
        overlays = nixpkgs.lib.optionals
          (nixpkgs.lib.hasSuffix "linux" system)
          [ lmSensorsOverlay ];
      });
    in
    {
      packages = ulib.forAllNative (system:
        let
          pkgs = nixpkgsFor.${system};
        in
        {
          # pkgsStatic on Linux yields a fully static musl binary.
          # On Darwin, libSystem must remain dynamic (Apple constraint), but
          # everything else (ncurses, etc.) is linked statically — the result
          # is portable across any macOS without a /nix/store.
          # stripAllList enables -s strip on $out/bin (default is -S, which
          # leaves part of the symbol table).
          default = pkgs.pkgsStatic.htop.overrideAttrs (old: {
            stripAllList = [ "bin" ];
          });
        });

      apps = ulib.forAllNative (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/htop";
        };
      });
    };
}
