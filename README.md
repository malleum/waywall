# Nixos WayWall MCSR
- Derivations
    - Waywall
    - Ninjabrain bot
    - glfw library
- My init.lua config 
    - Adapted from kuromi chloe
## Nixos
- to add the packages:
    - add this flake to your inputs
    - in systemPackages:
        - `inputs.waywall.packages.${pkgs.system}.waywall`
        - `inputs.waywall.packages.${pkgs.system}.ninjabrainbot`
        - `inputs.waywall.packages.${pkgs.system}.glfw`
