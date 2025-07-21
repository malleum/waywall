{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  jdk17,
  libxkbcommon,
  xorg,
  xkeyboard_config,
}:
stdenv.mkDerivation rec {
  pname = "ninjabrain-bot";
  version = "1.5.1";

  src = fetchurl {
    url = "https://github.com/Ninjabrain1/Ninjabrain-Bot/releases/download/${version}/Ninjabrain-Bot-${version}.jar";
    sha256 = "sha256-Rxu9A2EiTr69fLBUImRv+RLC2LmosawIDyDPIaRcrdw=";
  };

  nativeBuildInputs = [makeWrapper];

  # All required runtime libraries for the application to function correctly.
  runtimeLibs = [libxkbcommon xorg.libX11 xorg.libXt xorg.libXtst xorg.libXext xorg.libXi xorg.libXrender xorg.libXrandr xorg.libXfixes xorg.libxkbfile xkeyboard_config];

  # JRE and Xwayland are also build inputs.
  buildInputs = [ (jdk17.override {enableGtk = false;}) ] ++ runtimeLibs;

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/share/java
    cp $src $out/share/java/ninjabrain-bot.jar

    # This wrapper sets the necessary library path for all dependencies
    # and a required AWT flag for compatibility with modern window managers.
      # --set-default _JAVA_AWT_WM_NONREPARENTING 1 \
    makeWrapper ${jdk17}/bin/java $out/bin/ninjabrain-bot \
      --add-flags "-Dswing.defaultlaf=javax.swing.plaf.metal.MetalLookAndFeel -jar $out/share/java/ninjabrain-bot.jar" \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeLibs}
    runHook postInstall
  '';

  meta = with lib; {
    description = "Minecraft speedrunning advanced stronghold calculator";
    homepage = "https://github.com/Ninjabrain1/Ninjabrain-Bot";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
  };
}
