# The JDK Minecraft itself runs on, for MCSR.
#
# GraalVM's JIT (the Graal compiler via JVMCI, instead of C2) is the reason to
# bother: the hot paths in a speedrun are chunk generation and world load --
# long-running compiled code, which is exactly where Graal beats C2. It is a
# plain JDK, so Prism Launcher can be pointed at `${mcsr-jdk}/bin/java`.
#
# Oracle GraalVM for JDK 21, fetched from Oracle's archive rather than taken from
# nixpkgs. Both halves of that are deliberate:
#
#   JDK 21, not 25. The MCSR Java settings guide
#   <https://gist.github.com/maskersss/5847d594fc6ce4feb66fbd2d3fda281d> asks
#   for GraalVM 21 and warns off 23+ over Generational ZGC regressions. nixpkgs
#   carries only GraalVM 25 -- every older release is marked EOL and refuses to
#   evaluate -- so the tarball is pinned here instead.
#
#   Oracle GraalVM, not Community Edition. The enterprise compiler is what has
#   the tuning the guide recommends: on CE, -Dgraal.TuneInlinerExploration=1 is
#   rejected outright and the JVM refuses to start. It is also the faster JIT,
#   which is the whole reason to run GraalVM for a speedrun. The licence is
#   Oracle's GFTC -- free for any use, but unfree by nixpkgs' definition -- so
#   this needs allowUnfree.
#
# `buildGraalvm` is nixpkgs' own builder, so this still gets the same
# autoPatchelf and wrapper treatment as the packaged versions.
{
  lib,
  stdenv,
  fetchurl,
  graalvmPackages,
  # Static musl build. Only changes `native-image` output, which Minecraft does
  # not use.
  useMusl ? false,
}: let
  version = "21.0.10";

  srcs = {
    "x86_64-linux" = {
      url = "https://download.oracle.com/graalvm/21/archive/graalvm-jdk-${version}_linux-x64_bin.tar.gz";
      hash = "sha256-VgfTWtVspIQDBmfoheMXC0PIeXVPIY9GP5TnkbdHt/0=";
    };
    "aarch64-linux" = {
      url = "https://download.oracle.com/graalvm/21/archive/graalvm-jdk-${version}_linux-aarch64_bin.tar.gz";
      hash = "sha256-xj+Y8LyYJTgtEzS+/+9u2pff9B6M07ywlysK1fHkiUQ=";
    };
  };
in
  graalvmPackages.buildGraalvm {
    pname = "mcsr-jdk";
    inherit version useMusl;

    src = fetchurl srcs.${stdenv.hostPlatform.system};

    passthru = {
      # Paste these into Prism's per-instance "Java arguments". They live here as
      # data rather than in a wrapper script because Prism assembles the java
      # command line itself and would ignore a wrapper's --add-flags.
      #
      # This is the guide's set verbatim. All four were checked against this
      # exact JDK with -XX:+PrintFlagsFinal and show up as {command line}, so
      # none of them are silently ignored -- worth verifying, because two of
      # them are not portable: TuneInlinerExploration does not exist on GraalVM
      # CE (the JVM refuses to start), and NmethodSweepActivity is gone on
      # JDK 25, where the code cache sweeper it tunes no longer exists.
      jvmArgs = [
        # Matters most with SeedQueue, where G1 pauses during pregeneration show
        # up as stutter mid-run.
        "-XX:+UseZGC"
        # Commit the whole heap up front, so the first minutes of a run are not
        # paying for page faults.
        "-XX:+AlwaysPreTouch"
        # Spend more compile time exploring inlining decisions -- the right
        # trade for a ten-minute run.
        "-Dgraal.TuneInlinerExploration=1"
        # Sweep the code cache less aggressively, so hot methods are less likely
        # to be flushed and need recompiling mid-run.
        "-XX:NmethodSweepActivity=1"
      ];

      # Heap sizing, from the same guide: 2000-2500M normally, 2800-3000M at
      # high render distance, plus roughly 250M per queued seed under SeedQueue.
      heapMegabytes = 2500;
    };

    meta = {
      description = "Oracle GraalVM for JDK 21, as the JDK to run Minecraft on for MCSR";
      homepage = "https://www.graalvm.org/";
      # Oracle GraalVM Free Terms and Conditions.
      license = lib.licenses.unfree;
      mainProgram = "java";
      platforms = builtins.attrNames srcs;
    };
  }
