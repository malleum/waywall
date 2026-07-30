# Clicks-per-second overlay: a wlr-layer-shell client that reads left clicks
# straight off /dev/input and draws a decaying CPS figure with cairo.
#
# Because it talks to the host compositor's layer-shell rather than to waywall,
# it floats above the waywall window instead of being composited inside it. That
# is deliberate -- it keeps working across resolution toggles without waywall
# having to know about it.
{
  lib,
  stdenv,
  fetchFromGitHub,
  meson,
  ninja,
  pkg-config,
  wayland-scanner,
  wayland,
  cairo,
}:
stdenv.mkDerivation {
  pname = "cps-wl";
  version = "0.1.0-unstable-2026-03-11";

  src = fetchFromGitHub {
    owner = "malleum";
    repo = "cps_wl";
    rev = "4cc083a5b955cca61ba2f9cd3a2d1b10f9dea7d8";
    hash = "sha256-V9wcJlkW8gR/he5e8JCRogigvOVOgtis8i2A9e7HHX4=";
  };

  nativeBuildInputs = [meson ninja pkg-config wayland-scanner];
  buildInputs = [wayland cairo];

  meta = {
    description = "Wayland layer-shell overlay showing left-click CPS";
    homepage = "https://github.com/malleum/cps_wl";
    mainProgram = "cps-overlay";
    platforms = lib.platforms.linux;
  };
}
