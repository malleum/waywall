{
  description = "Minecraft speedrunning setup: waywall config, Ninjabrain-Bot, CPS overlay, MCSR JDK";

  inputs.nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

  outputs = {
    self,
    nixpkgs,
  }: let
    systems = ["x86_64-linux" "aarch64-linux"];
    forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
  in {
    packages = forAllSystems (pkgs: {
      ninjabrainbot = pkgs.callPackage ./nix/pkgs/ninjabrain-bot.nix {};
      cps-wl = pkgs.callPackage ./nix/pkgs/cps-wl.nix {};
      mcsr-jdk = pkgs.callPackage ./nix/pkgs/mcsr-jdk.nix {};
    });

    # Home-manager modules. `waywall` generates ~/.config/waywall/init.lua from
    # Nix options (colours, geometry, keybinds) and drives lua/main.lua out of
    # the store; `ninjabrain-bot` renders the bot's Java preferences file.
    homeModules = {
      waywall = import ./nix/modules/waywall.nix {inherit self;};
      ninjabrain-bot = import ./nix/modules/ninjabrain-bot.nix {inherit self;};
      default = {
        imports = [
          self.homeModules.waywall
          self.homeModules.ninjabrain-bot
        ];
      };
    };

    formatter = forAllSystems (pkgs: pkgs.alejandra);
  };
}
