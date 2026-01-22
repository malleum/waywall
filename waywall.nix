{
  lib,
  stdenv,
  fetchFromGitHub,
  libGL,
  libspng,
  libxkbcommon,
  luajit,
  meson,
  ninja,
  pkg-config,
  wayland,
  wayland-protocols,
  wayland-scanner,
  xorg,
  xwayland,
}:
stdenv.mkDerivation {
  pname = "waywall";
  version = "0.2026.01.11";

  src = fetchFromGitHub {
    owner = "tesselslate";
    repo = "waywall";
    rev = "603aab2b492dab40a8d088be1131cb282c1cd2a2";
    hash = "sha256-VOtwVFMGgUvsGnD1CnflKtUy5tTKqK2C/qNsWwgbyEU=";
  };

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
    wayland-scanner
  ];

  buildInputs = [
    libGL
    libspng
    libxkbcommon
    luajit
    wayland
    wayland-protocols
    xorg.libxcb
    xorg.libXcomposite
    xorg.libXres
    xorg.libXtst
    xwayland
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 waywall/waywall -t $out/bin

    runHook postInstall
  '';

  meta = {
    description = "Wayland compositor for Minecraft speedrunning";
    longDescription = ''
      Waywall is a Wayland compositor that provides various convenient
      features (key rebinding, Ninjabrain Bot support, etc) for Minecraft
      speedrunning. It is designed to be nested within an existing Wayland
      session and is intended as a successor to resetti.
    '';
    homepage = "https://tesselslate.github.io/waywall/";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    mainProgram = "waywall";
  };
}
