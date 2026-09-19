# waywall MCSR setup

Minecraft speedrunning setup for NixOS: a declaratively-generated
[waywall](https://github.com/tesselslate/waywall) config, Ninjabrain-Bot with a
generated preferences file, a clicks-per-second overlay, and the JDK to run the
game on.

This repository is both the flake and the waywall config directory — it is
checked out at `~/.config/waywall`, and `init.lua` is generated into that same
directory by home-manager (hence the `.gitignore` entry).

## Layout

    flake.nix
    lua/main.lua                    waywall scene engine, driven by a cfg table
    nix/pkgs/ninjabrain-bot.nix     the jar, wrapped with its runtime X libs
    nix/pkgs/cps-wl.nix             clicks-per-second layer-shell overlay
    nix/pkgs/perch.nix              open-to-LAN + dragon-perch ydotool script
    nix/pkgs/mcsr-jdk.nix           Oracle GraalVM 21 + the MCSR JVM args, as passthru
    nix/lib/assets.nix              border/crosshair PNGs, generated from colours
    nix/lib/gen-assets.py           the Pillow script assets.nix runs
    nix/lib/ninb-theme.nix          base16 -> Ninjabrain-Bot theme string
    nix/modules/waywall.nix         home-manager module -> init.lua
    nix/modules/ninjabrain-bot.nix  home-manager module -> prefs.xml
    resources/overlay.png           boat-eye pixel ruler overlay
    resize_animation_waywall.py     OBS script that tweens resolution changes

## Usage

Add the flake as an input, then import `homeModules.default` in a home-manager
configuration:

```nix
{
  imports = [inputs.waywall.homeModules.default];

  programs.waywall = {
    enable = true;
    colors.background = "#1a1b26";
    border.color = "#7aa2f7";
    measure.overlay = ./overlay.png;
    # ... see nix/modules/waywall.nix for the full option set
  };

  programs.ninjabrain-bot = {
    enable = true;
    stylix = true;
    base16Scheme = config.stylix.base16Scheme;
    settings.sensitivity = 0.02291165;
  };
}
```

A worked example, wired to a stylix palette, lives in
`~/.config/nixos/modules/programs/waywall.nix`.

### Design

Everything visual is derived rather than hand-drawn. `programs.waywall` knows
the canvas size and each alternate resolution, and waywall composites the game
1:1 and centred, so the module can compute exactly where the viewport lands and
generate a border image that frames it. The same goes for the pie chart and
percentage mirrors: their source rectangles are expressed relative to the thin
and tall resolutions, so changing a resolution moves them correctly instead of
silently mirroring the wrong pixels.

`lua/main.lua` holds the scene logic and takes no editing to retheme. It is
loaded out of the nix store by the generated `init.lua`, which is the only file
in this directory home-manager owns.

### Modes

| Bind          | Mode   | What it shows                                    |
| ------------- | ------ | ------------------------------------------------ |
| `M4`          | thin   | thin BT, pie chart + percentages + e-count       |
| `Shift-M4`    | wide   | wide stretch, no overlays                        |
| `F1`          | tall   | tall, plus the boat-eye measuring window         |
| `Ctrl-4`      | lowest | tall without the boat-eye window                 |
| `Ctrl-6`      | —      | flip between the MCSR and Dvorak keyboard layouts |
| `Ctrl-K`      | —      | show/hide Ninjabrain-Bot (starting it if needed) |
| `Ctrl-7`      | —      | start/stop the CPS overlay                       |
| `Ctrl-8`      | —      | show/hide the centre crosshair dot               |
| `Ctrl-9`      | —      | open to LAN with cheats, then perch the dragon   |

`tall` and `lowest` deliberately share one resolution, which is why the engine
tracks the mode itself instead of using `helpers.res_mirror`.

### One-cycle practice

`Ctrl-9` (`programs.waywall.perch.enable`) pauses, opens the world to LAN with
cheats on, and types

    /data merge entity @e[type=ender_dragon,limit=1] {DragonPhase:2}

which is phase "fly to the portal and land", so the dragon perches immediately
instead of finishing its circle. The menu path and the command are both taken
from [pjagada/minecraftahk](https://github.com/pjagada/minecraftahk) (`OpenToLAN`
and `Perch`), and hold for 1.16.x; 1.17+ walks the LAN screen differently.

It runs in phases against state-output rather than on a timer: opening to LAN
saves the world first, which blocks the render thread for one to five seconds,
and every key sent during that freeze is lost. Each step waits for the game to
report that it got there -- and chat must actually be open before anything is
typed, since into the world instead the command's letters are game binds.

The keys come from ydotool, not wtype: waywall implements neither
virtual-keyboard-unstable-v1 nor input-method, so a wtype client started inside
it has nothing to bind to, while ydotool writes to `/dev/uinput` and enters at
the host compositor. That needs `programs.ydotool.enable = true` on the system
and the user in `programs.ydotool.group`. For the duration of the script the
MCSR layout and its remaps are swapped for a plain US keymap, because ydotool
emits US scancodes and the layout would otherwise scramble the command.

## Minecraft JVM

`mcsr-jdk` is Oracle GraalVM for JDK 21 (unfree, Oracle's GFTC — needs
`allowUnfree`). Point Prism Launcher's Java path at it and take the arguments
from the package rather than retyping them:

```sh
nix build .#mcsr-jdk --no-link --print-out-paths   # Java path: <out>/bin/java
nix eval .#mcsr-jdk.jvmArgs --json                 # Java arguments
nix eval .#mcsr-jdk.heapMegabytes                  # baseline max heap
```

See the comments in `nix/pkgs/mcsr-jdk.nix` for why each flag is there, and why
this is Oracle GraalVM 21 rather than the GraalVM CE 25 in nixpkgs: two of the
four flags do not exist on that combination.

## Credits

- [tesselslate/waywall](https://github.com/tesselslate/waywall)
- [arjuncgore/waywall_generic_config](https://github.com/arjuncgore/waywall_generic_config)
  and the [Azusa fork](https://github.com/mrlascon-lgtm/waywall_Azusa_Nakano_config),
  for the pie-chart and percentage source rectangles and the border-overlay idea
- [althaea.zone/ninjabrain-bot-nix](https://tangled.org/althaea.zone/ninjabrain-bot-nix),
  for working out Ninjabrain-Bot's hotkey encoding and theme serialisation
- [the MCSR Java settings guide](https://gist.github.com/maskersss/5847d594fc6ce4feb66fbd2d3fda281d)
