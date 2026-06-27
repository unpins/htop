{
  description = "htop as a single self-contained binary";

  nixConfig = {
    extra-substituters = [ "https://unpins.cachix.org" ];
    extra-trusted-public-keys = [ "unpins.cachix.org-1:DDaShjbZ8VvcqxeTcAU3kV9vxZQBlyb7V/uLBHfTynI=" ];
  };

  inputs.unpins-lib.url = "github:unpins/nix-lib";

  # Bake the curated terminfo fallback into ncurses → libtinfo.a so htop renders
  # on hosts without /usr/share/terminfo (scratch/Alpine). Host terminfo still
  # wins when present.
  outputs = { self, unpins-lib }:
    unpins-lib.lib.mkStandaloneFlake {
      inherit self;
      name = "htop";

      engine = "unpin-llvm";
      multicall = {
        # The mega relinks from bitcode, so it can't see htop's own configure
        # -framework flags — declare them here so the mega-link names them.
        requires.frameworks = [ "IOKit" "CoreFoundation" ];
        programs = [{ name = "htop"; }];
      };

      build = pkgs:
        let
          p = pkgs.pkgsStatic;
          # Fallback terminfo is baked centrally for every engine ncurses, linux +
          # darwin (native-overlay/ncurses.nix), so p.ncurses already carries it.
          # libcap auto-enables Go bindings when `go` is on PATH, building
          # goapps htop never uses; force GOLANG=no.
          libcapNoGo = p.libcap.overrideAttrs (old: {
            makeFlags = (old.makeFlags or [ ]) ++ [ "GOLANG=no" ];
          });
        in
        if p.stdenv.hostPlatform.isLinux then
          (p.htop.override {
            ncurses = p.ncurses;
            libcap = libcapNoGo;
            # lm_sensors propagates perl+bash for sensors-detect, which we don't
            # ship; drop them and the script.
            lm_sensors = p.lm_sensors.overrideAttrs (old: {
              propagatedBuildInputs = p.lib.filter
                (i: !builtins.elem (i.pname or "") [ "perl" "bash" ])
                (old.propagatedBuildInputs or [ ]);
              postInstall = (old.postInstall or "") + ''
                rm -f $out/bin/sensors-detect $out/bin/sensors-conf-convert
                rm -f $out/sbin/sensors-detect $out/sbin/sensors-conf-convert
              '';
            });
          }).overrideAttrs (old: {
            # nixpkgs' postPatch rewrites linux/LibNl.c's `dlopen("libnl-3.so")`
            # (delay-acct, loaded at runtime) to the absolute `${libnl}/lib/...`
            # store path — a runtime-closure leak. In a static-musl binary dlopen
            # can't load anyway, so the path is pure dead-weight leak; restore the
            # upstream bare sonames (libnl-3.so / .so.200, libnl-genl-3.so / .200)
            # so nothing references the store. The feature stays enabled (it just
            # no-ops here, as it already did), and works if ever linked dynamic.
            postPatch = (old.postPatch or "") + ''
              substituteInPlace linux/LibNl.c \
                --replace-fail '${p.lib.getLib p.libnl}/lib/libnl-3.so' 'libnl-3.so' \
                --replace-fail '${p.lib.getLib p.libnl}/lib/libnl-genl-3.so' 'libnl-genl-3.so'
            '';
          })
        else
          # darwin: the SDK-always engine gives htop's platform code the SDK
          # headers + frameworks; ncurses fallback-terminfo is centralized, so
          # plain pkgsStatic.htop is enough.
          p.htop;
    };
}
