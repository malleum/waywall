# The JDK Minecraft itself runs on, for MCSR.
#
# GraalVM's JIT (the Graal compiler via JVMCI, instead of C2) is the reason to
# bother: the hot paths in a speedrun are chunk generation and world load --
# long-running compiled code, which is exactly where Graal beats C2. It is a
# plain JDK, so Prism Launcher can be pointed at `${mcsr-jdk}/bin/java`.
#
# Version note: the MCSR Java settings guide
# <https://gist.github.com/maskersss/5847d594fc6ce4feb66fbd2d3fda281d> asks for
# GraalVM 21 and warns off 23+ over Generational ZGC regressions. nixpkgs only
# carries GraalVM 25 -- every older release is marked EOL and refuses to
# evaluate -- so 25 is what this is. If ZGC turns out to stutter, drop
# `-XX:+UseZGC` from `jvmArgs` to fall back to G1 rather than chasing an
# unpackaged older JDK.
{graalvmPackages}:
graalvmPackages.graalvm-ce.overrideAttrs (old: {
  passthru =
    (old.passthru or {})
    // {
      # Paste these into Prism's per-instance "Java arguments". They live here
      # as data rather than in a wrapper script because Prism assembles the
      # java command line itself, and would ignore a wrapper's --add-flags.
      #
      # Verified to start GraalVM CE 25.0.2. Two flags from the guide are
      # deliberately absent:
      #   -Dgraal.TuneInlinerExploration=1  Oracle GraalVM (enterprise) only;
      #                                     CE rejects it outright and the JVM
      #                                     refuses to start.
      #   -XX:NmethodSweepActivity=1        the code cache sweeper it tuned was
      #                                     removed in JDK 20.
      jvmArgs = [
        "-XX:+UnlockExperimentalVMOptions"
        # Matters most with SeedQueue, where G1 pauses during pregeneration show
        # up as stutter mid-run.
        "-XX:+UseZGC"
        # Commit the whole heap up front, so the first minutes of a run are not
        # paying for page faults.
        "-XX:+AlwaysPreTouch"
        # Initialise the Graal compiler at startup rather than lazily, so early
        # code gets Graal-compiled instead of C2-compiled.
        "-XX:+EagerJVMCI"
      ];

      # Heap sizing, from the same guide: 2000-2500M normally, 2800-3000M at
      # high render distance, plus roughly 250M per queued seed under SeedQueue.
      heapMegabytes = 2500;
    };

  meta =
    old.meta
    // {
      description = "GraalVM CE 25, as the JDK to run Minecraft on for MCSR";
    };
})
