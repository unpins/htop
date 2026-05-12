{
  description = "Standalone build of htop";

  nixConfig = {
    extra-substituters = [ "https://unpins.cachix.org" ];
    extra-trusted-public-keys = [ "unpins.cachix.org-1:DDaShjbZ8VvcqxeTcAU3kV9vxZQBlyb7V/uLBHfTynI=" ];
  };

  inputs.unpins-lib.url = "github:unpins/nix-lib/v1";

  outputs = { self, unpins-lib }:
    let ulib = unpins-lib.lib;
    in
    ulib.mkStandaloneFlake {
      inherit self;
      name = "htop";
      build = pkgs:
        if pkgs.stdenv.hostPlatform.isDarwin
        then (ulib.pkgsDarwinStatic pkgs).htop
        else (ulib.slimLmSensors pkgs).pkgsStatic.htop;
    };
}
