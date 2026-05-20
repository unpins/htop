{
  description = "Standalone build of htop";

  nixConfig = {
    extra-substituters = [ "https://unpins.cachix.org" ];
    extra-trusted-public-keys = [ "unpins.cachix.org-1:DDaShjbZ8VvcqxeTcAU3kV9vxZQBlyb7V/uLBHfTynI=" ];
  };

  inputs.unpins-lib.url = "github:unpins/nix-lib";

  # linux: htop's lm_sensors propagates perl+bash for sensors-detect (we
  # don't ship it). Slim both and rm the script.
  # All platforms: bake the curated terminfo fallback list into ncurses
  # → libtinfo.a so htop renders correctly on hosts without
  # `/usr/share/terminfo` (scratch/Alpine/minimal). Host terminfo still
  # wins when present.
  outputs = { self, unpins-lib }:
    unpins-lib.lib.mkStandaloneFlake {
      inherit self;
      name = "htop";
      build = pkgs:
        let
          p = pkgs.pkgsStatic;
          ncursesFB = unpins-lib.lib.embedFallbackTerminfo p.ncurses;
          # libcap's Make.Rules auto-enables Go bindings whenever a `go`
          # binary is on PATH (`GOLANG ?= $(shell if go version; then
          # yes; else no; fi)`). In our LTO chain that auto-detects yes
          # and tries to build `goapps/web` etc. cgo'd against libcap.a;
          # the .o files cgo generates carry fat-LTO bitcode side, and
          # Go's cgo loader bails with `cannot load DWARF output from
          # $WORK/.../_cgo_.o: decoding dwarf section info at offset
          # 0x0: too short` (the bitcode-side DWARF stub isn't a real
          # DWARF section). We don't ship libcap's Go helpers anyway —
          # they're separate `web`/`setid`/`gowns` binaries htop never
          # uses — so force GOLANG=no, which lets the C side of libcap
          # (libcap.a / libpsx.a) build clean with full LTO.
          libcapNoGo = p.libcap.overrideAttrs (old: {
            makeFlags = (old.makeFlags or [ ]) ++ [ "GOLANG=no" ];
          });
        in
        if p.stdenv.hostPlatform.isLinux then
          p.htop.override {
            ncurses = ncursesFB;
            libcap = libcapNoGo;
            lm_sensors = p.lm_sensors.overrideAttrs (old: {
              propagatedBuildInputs = p.lib.filter
                (i: !builtins.elem (i.pname or "") [ "perl" "bash" ])
                (old.propagatedBuildInputs or [ ]);
              postInstall = (old.postInstall or "") + ''
                rm -f $out/bin/sensors-detect $out/bin/sensors-conf-convert
                rm -f $out/sbin/sensors-detect $out/sbin/sensors-conf-convert
              '';
            });
          }
        else
          p.htop.override { ncurses = ncursesFB; };
    };
}
