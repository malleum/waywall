{
  description = "waywall";

  inputs.nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

  outputs = inputs: let
    system = "x86_64-linux";
    pkgs = import inputs.nixpkgs {inherit system;};
  in {
    packages."${system}" = {
      ninjabrainbot = pkgs.callPackage ./ninjabrain-bot.nix;
      glfw = pkgs.callPackage ./glfw.nix;
      waywall = pkgs.callPackage ./waywall.nix;
    };
  };
}
