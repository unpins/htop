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
      lib = nixpkgs.lib;

      # lm_sensors propagates perl + bash for sensors-detect, which we don't ship.
      lmSensorsOverlay = _final: prev: {
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
        overlays = lib.optionals (lib.hasSuffix "linux" system) [ lmSensorsOverlay ];
      });

      # On Darwin pkgsStatic breaks: libSystem must stay dynamic, but
      # --disable-shared kills the configure link tests. Use regular
      # darwin htop with ncurses built static-only via its own knob —
      # ulib.staticOnlyAuto can't help because ncurses uses
      # --with-shared/--without-shared, not --enable-shared/--disable-shared.
      buildHtop = pkgs:
        let
          htopDrv =
            if pkgs.stdenv.hostPlatform.isDarwin
            then pkgs.htop.override {
              ncurses = pkgs.ncurses.override { enableStatic = true; };
            }
            else pkgs.pkgsStatic.htop;
        in
        htopDrv.overrideAttrs (_: {
          stripAllList = [ "bin" ];
        });
    in
    {
      packages = ulib.forAllNative (system:
        let pkgs = nixpkgsFor.${system}; in
        {
          default = buildHtop pkgs;
        } // lib.optionalAttrs (system == "aarch64-darwin") {
          "darwin-x86_64" = buildHtop pkgs.pkgsCross.x86_64-darwin;
        });

      apps = ulib.forAllNative (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/htop";
        };
      });
    };
}
