{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchurl,
  cmake,
  pkg-config,
  libGL,
  libGLU,
  wayland,
  wayland-protocols,
  wayland-scanner,
  libxkbcommon,
  libffi,
  xorg,
}:
stdenv.mkDerivation rec {
  pname = "glfw-patched";
  version = "3.4";

  src = fetchFromGitHub {
    owner = "glfw";
    repo = "glfw";
    rev = version;
    sha256 = "sha256-FcnQPDeNHgov1Z07gjFze0VMz2diOrpbKZCsI96ngz0=";
  };

  patch = fetchurl {
    url = "https://raw.githubusercontent.com/tesselslate/waywall/be3e018bb5f7c25610da73cc320233a26dfce948/contrib/glfw.patch";
    sha256 = "sha256-kl3DFYVfUe4CPBSuh3DJxDpYvg8vFxq8F+RR9sG+EHE=";
  };

  patches = [patch];

  nativeBuildInputs = [
    cmake
    pkg-config
    wayland-scanner
  ];

  buildInputs = [
    libGL
    libGLU
    wayland
    wayland-protocols
    libxkbcommon
    libffi
    xorg.libX11
    xorg.libXi
    xorg.libXrandr
    xorg.libXcursor
    xorg.libXinerama
    xorg.libXxf86vm
    xorg.libXcomposite
    xorg.libXres
    xorg.libXtst
  ];

  cmakeFlags = [
    "-DBUILD_SHARED_LIBS=ON"
    "-DGLFW_BUILD_WAYLAND=ON"
    "-DGLFW_BUILD_X11=ON"
    "-DGLFW_BUILD_EXAMPLES=OFF"
    "-DGLFW_BUILD_TESTS=OFF"
    "-DGLFW_BUILD_DOCS=OFF"
  ];

  meta = with lib; {
    description = "Multi-platform library for OpenGL, OpenGL ES, Vulkan, window and input (patched version)";
    homepage = "https://www.glfw.org/";
    license = licenses.zlib;
    platforms = platforms.unix;
  };
}
