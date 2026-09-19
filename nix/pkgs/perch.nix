# One-cycle practice helper: opens the world to LAN with cheats on, then runs
# the command that puts the ender dragon straight into its perch, so a perch
# attempt can be retried without setting the world up by hand.
#
# It is keyboard automation because Minecraft exposes none of this to commands:
# "Open to LAN" and "Allow Cheats" are buttons. The pause and LAN screens are
# walked with Tab/Shift-Tab the same way the 1.16+ AutoHotkey reset macros do
# it (pjagada/minecraftahk, `OpenToLAN()` + `Perch()`), which is also where the
# dragon command itself comes from:
#
#   /data merge entity @e[type=ender_dragon,limit=1] {DragonPhase:2}
#
# DragonPhase 2 is "fly to the portal and land", i.e. it perches immediately
# instead of finishing the current circle. 1.16.1 and 1.16.5 share this one;
# only 1.17+ needs a different *menu* path (one more Tab), which is what the
# shift-tab counts below are for.
#
# The input has to come from ydotool rather than wtype: waywall implements
# neither virtual-keyboard-unstable-v1 nor input-method (its server/ directory
# has no such file), so a wtype client started inside waywall finds no protocol
# to bind. ydotool writes to /dev/uinput instead, so the events enter at the
# host compositor and reach Minecraft through waywall like any real key.
{
  lib,
  writeShellApplication,
  ydotool,
  coreutils,
  gnugrep,
}: {
  dragonCommand,
  pauseShiftTabs,
  lanShiftTabs,
  screenDelay,
  hostDelay,
  hostTimeout,
  logFile,
  doneFile,
  keyDelay,
}:
writeShellApplication {
  name = "waywall-perch";

  runtimeInputs = [ydotool coreutils gnugrep];

  text = ''
    # waywall.exec inherits waywall's own environment, which is the session's,
    # so YDOTOOL_SOCKET is normally already set by the NixOS module; the
    # fallback is that module's socket path.
    export YDOTOOL_SOCKET="''${YDOTOOL_SOCKET:-/run/ydotoold/socket}"

    done_file=${lib.escapeShellArg doneFile}
    log_file=${lib.escapeShellArg (
      if logFile == null
      then ""
      else toString logFile
    )}
    dragon_command=${lib.escapeShellArg dragonCommand}

    # The caller (lua/main.lua) waits on this file to know when it is safe to
    # put the MCSR keymap back, so it must not be left over from a past run.
    rm -f "$done_file"

    # Keycodes are evdev, from linux/input-event-codes.h:
    #   Esc 1, Tab 15, Enter 28, LeftShift 42, Slash 53.
    key() { ydotool key --key-delay ${toString keyDelay} "$@"; }

    # sleep(1) wants seconds; every delay here is configured in milliseconds.
    ms() { sleep "$(printf '%d.%03d' "$(($1 / 1000))" "$(($1 % 1000))")"; }

    shift_tab() {
      local n=$1 i args
      args=(42:1)
      for ((i = 0; i < n; i++)); do
        args+=(15:1 15:0)
      done
      args+=(42:0)
      key "''${args[@]}"
    }

    # Byte offset to start reading the log from, so the wait below cannot be
    # satisfied by a "Local game hosted on port" line from an earlier world.
    offset=1
    if [ -n "$log_file" ] && [ -r "$log_file" ]; then
      offset=$(($(wc -c < "$log_file") + 1))
    fi

    # Pause menu. Shift-Tab walks up from the bottom of the button list, so the
    # count depends on what mods have added to that screen (fast-reset adds one).
    key 1:1 1:0
    ms ${toString screenDelay}
    shift_tab ${toString pauseShiftTabs}
    key 28:1 28:0

    # LAN screen: toggle "Allow Cheats" on, then Tab onto "Start LAN World".
    ms ${toString screenDelay}
    shift_tab ${toString lanShiftTabs}
    key 28:1 28:0
    ms ${toString screenDelay}
    key 15:1 15:0
    key 28:1 28:0

    # Typing the command before the integrated server is up loses it, so wait
    # for the chat line that says the world is hosted. Without a log file to
    # watch there is nothing to wait on but the clock.
    if [ -n "$log_file" ]; then
      deadline=$(($(date +%s%3N) + ${toString hostTimeout}))
      until tail -c "+$offset" "$log_file" 2>/dev/null |
        grep -q "Local game hosted on port"; do
        if [ "$(date +%s%3N)" -ge "$deadline" ]; then
          break
        fi
        ms 25
      done
    else
      ms ${toString hostDelay}
    fi

    # Slash opens chat already holding the command prefix, so the text typed
    # here is the command without its leading "/".
    key 53:1 53:0
    ms ${toString screenDelay}
    ydotool type --key-delay ${toString keyDelay} "$dragon_command"
    key 28:1 28:0

    : > "$done_file"
  '';

  meta = {
    description = "Open a Minecraft world to LAN with cheats and force the dragon to perch";
    mainProgram = "waywall-perch";
  };
}
