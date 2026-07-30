# Builds the PNG overlays waywall draws on top of the game: one border image
# per alternate resolution, plus the crosshair dot.
#
# These are derived rather than checked in so that a change to the stylix
# palette or to a panel coordinate in Nix propagates to the pixels without
# anyone opening an image editor.
{
  runCommand,
  python3,
}: spec: let
  python = python3.withPackages (ps: [ps.pillow]);
in
  runCommand "waywall-assets" {
    nativeBuildInputs = [python];
    specJson = builtins.toJSON spec;
    passAsFile = ["specJson"];
  } ''
    mkdir -p $out
    python3 ${./gen-assets.py} $out < "$specJsonPath"
  ''
