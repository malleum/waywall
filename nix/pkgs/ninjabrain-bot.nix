{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  jre,
  libxkbcommon,
  libX11,
  libxt,
  libxtst,
  libxext,
  libxi,
  libxrender,
  libxrandr,
  libxfixes,
  libxkbfile,
  xkeyboard_config,
}:
stdenv.mkDerivation rec {
  pname = "ninjabrain-bot";
  version = "1.5.2";

  src = fetchurl {
    url = "https://github.com/Ninjabrain1/Ninjabrain-Bot/releases/download/${version}/Ninjabrain-Bot-${version}.jar";
    sha256 = "sha256-mAmfYyGpDUrOwTQA6G0F96+NYOVjnC84Qn6WjccUUP8=";
  };

  nativeBuildInputs = [makeWrapper];

  # jnativehook (the global hotkey listener) dlopens these at runtime, so they
  # have to be on LD_LIBRARY_PATH rather than merely present at build time.
  runtimeLibs = [
    libxkbcommon
    libX11
    libxt
    libxtst
    libxext
    libxi
    libxrender
    libxrandr
    libxfixes
    libxkbfile
    xkeyboard_config
  ];

  buildInputs = [jre] ++ runtimeLibs;

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/share/java
    cp $src $out/share/java/ninjabrain-bot.jar

    # Metal look-and-feel: the default GTK LaF renders a blank window under
    # several Wayland compositors, waywall's included.
    makeWrapper ${jre}/bin/java $out/bin/ninjabrain-bot \
      --add-flags "-Dswing.defaultlaf=javax.swing.plaf.metal.MetalLookAndFeel -jar $out/share/java/ninjabrain-bot.jar" \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeLibs}
    runHook postInstall
  '';

  meta = {
    description = "Minecraft speedrunning advanced stronghold calculator";
    homepage = "https://github.com/Ninjabrain1/Ninjabrain-Bot";
    license = lib.licenses.gpl3Plus;
    mainProgram = "ninjabrain-bot";
    platforms = lib.platforms.linux;
  };
}
