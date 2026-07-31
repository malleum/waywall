# Declarative waywall configuration.
#
# waywall is configured in Lua, so this module does not try to replace that: it
# generates a small `init.lua` holding a `cfg` table and hands it to the engine
# in lua/main.lua, which lives in the nix store. Colours, geometry and keybinds
# therefore come from Nix (and, via the caller, from stylix), while the actual
# scene logic stays readable Lua that can be diffed against upstream configs.
#
# Only ~/.config/waywall/init.lua is owned by this module. The runtime state
# files waywall writes next to it (layout_state.lua) are left alone.
{self}: {
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.programs.waywall;

  # Where the game's viewport lands in canvas coordinates for a given render
  # resolution. waywall composites the instance 1:1 and centres it, cropping
  # rather than scaling when it overflows (waywall/server/ui.c:layout_centered),
  # so a 384x16384 tall render shows up as a 384px-wide full-height column and
  # not as a 34px sliver.
  viewport = res: let
    w = lib.min res.w cfg.canvas.width;
    h = lib.min res.h cfg.canvas.height;
  in {
    inherit w h;
    x = (cfg.canvas.width - w) / 2;
    y = (cfg.canvas.height - h) / 2;
  };

  pad = cfg.border.padding;

  box = {
    x,
    y,
    w,
    h,
  }: {
    x = x - pad;
    y = y - pad;
    w = w + 2 * pad;
    h = h + 2 * pad;
  };

  ecountWidth = builtins.floor ((
      if cfg.panel.ecount.showChunkCache
      then 49
      else 37
    )
    * cfg.panel.ecount.scale);
  ecountHeight = builtins.floor ((
      if cfg.panel.ecount.showChunkCache
      then 18
      else 9
    )
    * cfg.panel.ecount.scale);

  # Just the e-count, for when the debug overlay is up but the profiler pie is
  # not: a full-height panel frame around an empty rectangle looks broken.
  ecountBox = box {
    inherit (cfg.panel.ecount) x y;
    w = ecountWidth;
    h = ecountHeight;
  };

  # The whole right-hand instrument cluster: e-count, pie chart and percentages.
  # One box around all three reads as a panel rather than three floating widgets.
  panelBox = let
    left = lib.min cfg.panel.pie.x cfg.panel.ecount.x;
    right =
      lib.max
      (cfg.panel.pie.x + builtins.floor (420 * cfg.panel.pie.scale))
      (cfg.panel.ecount.x + ecountWidth);
    top = lib.min cfg.panel.ecount.y cfg.panel.pie.y;
    bottom = cfg.panel.percent.y + builtins.floor (25 * cfg.panel.percent.scale);
  in
    box {
      x = left;
      y = top;
      w = right - left;
      h = bottom - top;
    };

  # The boat-eye window is a mirror, not the game surface, so unlike the game
  # boxes its frame has to be drawn *above* what it frames -- see the depth
  # comments in lua/main.lua. It needs corner masking for the same reason the
  # game boxes do: the mirror is rectangular and shows past the rounded corners.
  measureBox =
    (box {
      inherit (cfg.measure) x y;
      w = cfg.measure.width;
      h = cfg.measure.height;
    })
    // {mask = cfg.border.maskCorners;};

  # Border around the game viewport. On the axis where the render fills the
  # canvas (height, in every mode but wide) there is no room outside the game to
  # put the stroke, so the box is clamped to the canvas instead of padded
  # outward. That trades the outermost few rows of the view -- sky and ground
  # extremes, which nothing is read from -- for a border whose rounded corners
  # are actually on screen rather than cropped away.
  gameBox = res: let
    v = viewport res;
    x0 = lib.max 0 (v.x - pad);
    y0 = lib.max 0 (v.y - pad);
    x1 = lib.min cfg.canvas.width (v.x + v.w + pad);
    y1 = lib.min cfg.canvas.height (v.y + v.h + pad);
  in {
    x = x0;
    y = y0;
    w = x1 - x0;
    h = y1 - y0;
    # Minecraft renders a rectangle, so without this the game shows past each
    # rounded corner. Only the game boxes need it; the panel and measuring boxes
    # sit on the background already.
    mask = cfg.border.maskCorners;
  };

  # `lowest` renders at the tall resolution for the vertical precision, then
  # mirrors a centre slice of it into a shorter rectangle. That is the only way to
  # get both: waywall composites the instance 1:1 and crops, so a 16384-tall
  # render always fills the canvas height and cannot be shown shorter -- while
  # rendering at 864 to get the height back would restore the full ~70 degree
  # vertical FOV and throw the zoom away. Mirroring keeps the tall render and
  # shows a few degrees of it across 864 pixels.
  lowestDst = {
    x = (cfg.canvas.width - cfg.lowest.width) / 2;
    y = (cfg.canvas.height - cfg.lowest.height) / 2;
    w = cfg.lowest.width;
    h = cfg.lowest.height;
  };

  lowestSrc = {
    x = (cfg.lowest.render.w - cfg.lowest.srcWidth) / 2;
    y = (cfg.lowest.render.h - cfg.lowest.srcHeight) / 2;
    w = cfg.lowest.srcWidth;
    h = cfg.lowest.srcHeight;
  };

  lowestBox = (box lowestDst) // {mask = cfg.border.maskCorners;};

  assets = import ../lib/assets.nix {inherit (pkgs) runCommand python3;} {
    canvas = {
      w = cfg.canvas.width;
      h = cfg.canvas.height;
    };
    border = {
      inherit (cfg.border) color width radius opacity;
      cornerFill =
        if cfg.border.maskCorners
        then cfg.colors.background
        else null;
    };
    crosshair = {
      inherit (cfg.crosshair) color size opacity;
    };

    # Frames and panels are separate images rather than one image per
    # (mode x panel state) combination: the game frame depends only on the
    # resolution, the panel only on what the debug overlay is showing, and
    # multiplying them out would mean nine near-identical PNGs.
    images = {
      frame_thin.rects = [(gameBox cfg.resolutions.thin)];
      frame_wide.rects = [(gameBox cfg.resolutions.wide)];
      frame_tall.rects = [(gameBox cfg.resolutions.tall)];

      # Paints out the strips of the real viewport above and below the mirrored
      # slice, which would otherwise show the scene continuing past the border.
      # Goes under the mirror, at the depth where the instance also sits.
      cover_lowest.fills = [
        {
          outer = gameBox cfg.lowest.render;
          inner = lowestBox;
        }
      ];

      # These two frame a *mirror*, so unlike the game frames they have to be
      # drawn above what they frame -- see the depth comments in lua/main.lua.
      frame_lowest.rects = [lowestBox];
      frame_measure.rects = [measureBox];

      panel_full.rects = [panelBox];
      panel_ecount.rects = [ecountBox];
    };
  };

  # Serialise a Nix value as a Lua literal. Restricted on purpose to the shapes
  # the cfg table actually uses -- a general converter would be more code and
  # would hide typos that this one turns into an eval error.
  #
  # Numbers go through toJSON rather than toString: toString rounds floats to
  # six decimal places, which would quietly truncate a measured mouse
  # sensitivity like 3.7385416219369882 into a different sensitivity.
  toLua = indent: value: let
    pad = lib.strings.replicate indent "  ";
    inner = pad + "  ";
  in
    if value == null
    then "nil"
    else if builtins.isBool value
    then
      (
        if value
        then "true"
        else "false"
      )
    else if builtins.isInt value || builtins.isFloat value
    then builtins.toJSON value
    else if builtins.isString value
    then builtins.toJSON value
    else if builtins.isList value
    then "{" + lib.concatMapStringsSep ", " (toLua indent) value + "}"
    else if builtins.isAttrs value
    then
      "{\n"
      + lib.concatStrings (lib.mapAttrsToList (
          k: v: "${inner}[${builtins.toJSON k}] = ${toLua (indent + 1) v},\n"
        )
        value)
      + pad
      + "}"
    else throw "programs.waywall: cannot convert ${builtins.typeOf value} to Lua";

  luaConfig = {
    canvas = {
      w = cfg.canvas.width;
      h = cfg.canvas.height;
    };
    canvas_rect = {
      x = 0;
      y = 0;
      w = cfg.canvas.width;
      h = cfg.canvas.height;
    };

    colors = {
      inherit (cfg.colors) background text;
      pie_1 = cfg.colors.pie1;
      pie_2 = cfg.colors.pie2;
      pie_3 = cfg.colors.pie3;
    };
    percent_match_text = cfg.panel.percent.matchText;

    res = {
      thin = cfg.resolutions.thin;
      wide = cfg.resolutions.wide;
      tall = cfg.resolutions.tall;
      # `lowest` renders tall but is displayed through a mirror, hence the pair
      # of rects below rather than just a size.
      lowest = cfg.lowest.render;
    };

    lowest = {
      src = lowestSrc;
      dst = lowestDst;
    };

    sensitivity = {
      inherit (cfg.sensitivity) base thin wide tall lowest;
    };

    inherit (cfg) repeat_rate repeat_delay confine_pointer;

    layouts = {
      mcsr = {
        inherit (cfg.layouts.mcsr) layout variant remaps;
      };
      alt = {
        inherit (cfg.layouts.alt) layout variant remaps;
      };
    };

    panel = {
      inherit (cfg.panel) frame;
      pie = {inherit (cfg.panel.pie) x y scale;};
      percent = {inherit (cfg.panel.percent) x y scale;};
      ecount = {
        inherit (cfg.panel.ecount) x y scale;
        show_chunk_cache = cfg.panel.ecount.showChunkCache;
      };
    };

    measure = {
      src_w = cfg.measure.srcWidth;
      src_h = cfg.measure.srcHeight;
      dst = {
        inherit (cfg.measure) x y;
        w = cfg.measure.width;
        h = cfg.measure.height;
      };
    };

    crosshair_rect = {
      x = (cfg.canvas.width - cfg.crosshair.size) / 2;
      y = (cfg.canvas.height - cfg.crosshair.size) / 2;
      w = cfg.crosshair.size;
      h = cfg.crosshair.size;
    };

    assets = {
      frame_thin = "${assets}/frame_thin.png";
      frame_wide = "${assets}/frame_wide.png";
      frame_tall = "${assets}/frame_tall.png";
      frame_lowest = "${assets}/frame_lowest.png";
      cover_lowest = "${assets}/cover_lowest.png";
      frame_measure = "${assets}/frame_measure.png";
      panel_full = "${assets}/panel_full.png";
      panel_ecount = "${assets}/panel_ecount.png";
      crosshair = "${assets}/crosshair.png";
      measure_overlay = toString cfg.measure.overlay;
    };

    ninb = {
      anchor = cfg.ninb.anchor;
      opacity = cfg.ninb.opacity;
      command = cfg.ninb.command;
      process = cfg.ninb.process;
    };

    cps = {
      toggle_command = cfg.cps.toggleCommand;
    };

    paceman = {
      inherit (cfg.paceman) enable command process;
    };

    keys = cfg.keys;

    resize_animation = cfg.resizeAnimation.enable;
    res_state_file = cfg.resizeAnimation.stateFile;
    layout_state_file = "${config.xdg.configHome}/waywall/layout_state.lua";
  };

  initLua = ''
    -- Generated by programs.waywall (nix/modules/waywall.nix). Do not edit:
    -- change the Nix options and rebuild. The scene logic this drives lives in
    -- ${self}/lua/main.lua.
    local cfg = ${toLua 0 luaConfig}

    return assert(loadfile("${self}/lua/main.lua"))()(cfg)
  '';

  resType = lib.types.submodule {
    options = {
      w = lib.mkOption {
        type = lib.types.ints.positive;
        description = "Render width.";
      };
      h = lib.mkOption {
        type = lib.types.ints.positive;
        description = "Render height.";
      };
    };
  };

  mkColor = default: description:
    lib.mkOption {
      type = lib.types.strMatching "#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?";
      inherit default description;
    };
in {
  options.programs.waywall = {
    enable = lib.mkEnableOption "waywall with a generated init.lua";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.waywall;
      defaultText = lib.literalExpression "pkgs.waywall";
      description = "waywall package to install.";
    };

    canvas = {
      width = lib.mkOption {
        type = lib.types.ints.positive;
        default = 1920;
        description = ''
          Width waywall renders at while fullscreened. All overlay coordinates
          are in this space, so it should match the monitor (or the OBS canvas,
          if those differ and OBS is what matters).
        '';
      };
      height = lib.mkOption {
        type = lib.types.ints.positive;
        default = 1080;
        description = "Height waywall renders at while fullscreened.";
      };
    };

    colors = {
      background = mkColor "#000000" ''
        Fill behind the game, visible whenever the instance does not cover the
        whole canvas (thin, wide, tall).
      '';
      text = mkColor "#ffffff" "Recoloured F3 text (e-count).";
      pie1 = mkColor "#f7768e" "Pie chart: block entities.";
      pie2 = mkColor "#7aa2f7" "Pie chart: unspecified, destroyProgress, prepare.";
      pie3 = mkColor "#bb9af7" "Pie chart: entities.";
    };

    border = {
      color = mkColor "#7aa2f7" "Outline colour for the window and panel borders.";
      width = lib.mkOption {
        type = lib.types.ints.positive;
        default = 3;
        description = "Outline thickness in canvas pixels.";
      };
      radius = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 20;
        description = "Corner radius, clamped per-rectangle to half its shorter side.";
      };
      opacity = lib.mkOption {
        type = lib.types.numbers.between 0.0 1.0;
        default = 1.0;
        description = "Border alpha multiplier.";
      };
      padding = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 6;
        description = ''
          Gap between a border and the thing it frames. The stroke is drawn
          inside its rectangle, so this is the only thing keeping it off the
          game's edge pixels.
        '';
      };
      maskCorners = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Paint the four corner wedges of the game viewport that fall outside the
          rounded border with `colors.background`. Minecraft renders a rectangle,
          so without this a sliver of game shows past each rounded corner.

          Assumes the background is a solid colour; with a background image the
          wedges would read as four flat patches instead.
        '';
      };
    };

    crosshair = {
      color = mkColor "#f7768e" "Centre dot colour.";
      size = lib.mkOption {
        type = lib.types.ints.positive;
        default = 9;
        description = "Diameter of the centre dot in canvas pixels.";
      };
      opacity = lib.mkOption {
        type = lib.types.numbers.between 0.0 1.0;
        default = 0.9;
        description = "Centre dot alpha.";
      };
    };

    resolutions = {
      thin = lib.mkOption {
        type = resType;
        default = {
          w = 340;
          h = 1080;
        };
        description = "Thin BT resolution.";
      };
      wide = lib.mkOption {
        type = resType;
        default = {
          w = 1920;
          h = 300;
        };
        description = "Wide (eye-zoom / nether travel) resolution.";
      };
      tall = lib.mkOption {
        type = resType;
        default = {
          w = 384;
          h = 16384;
        };
        description = "Tall resolution, for tall BT and boat eye.";
      };
    };

    # `lowest` is not a plain resolution like the others: the instance renders
    # tall (for boat-eye vertical precision) and only a centred slice of it is
    # mirrored onto screen, shorter than the render itself. See the `lowestDst`
    # /`lowestSrc` comment above for why this can't just be a resType.
    lowest = {
      render = lib.mkOption {
        type = resType;
        default = {
          w = 384;
          h = 16384;
        };
        description = "Render resolution `lowest` mode uses -- same as `tall`, for the same eye-throw precision.";
      };
      srcWidth = lib.mkOption {
        type = lib.types.ints.positive;
        default = 384;
        description = "Width, in render pixels, of the centred slice mirrored on screen.";
      };
      srcHeight = lib.mkOption {
        type = lib.types.ints.positive;
        default = 864;
        description = ''
          Height, in render pixels, of the centred slice mirrored on screen. 864
          of a 16384px-tall render is a few degrees of vertical FOV, i.e. zoomed
          in further than `tall`'s direct view.
        '';
      };
      width = lib.mkOption {
        type = lib.types.ints.positive;
        default = 384;
        description = "On-screen width of the mirrored slice.";
      };
      height = lib.mkOption {
        type = lib.types.ints.positive;
        default = 864;
        description = ''
          On-screen height of the mirrored slice. 864 of a 1080 canvas is 80%
          screen height. Pie chart and percentage source rects are derived from
          this, so they stay aimed correctly if it changes.
        '';
      };
    };

    sensitivity = {
      base = lib.mkOption {
        type = lib.types.numbers.nonnegative;
        default = 1.0;
        description = ''
          Camera sensitivity multiplier at normal resolution. Only applies with
          Raw Input off ingame.
        '';
      };
      thin = lib.mkOption {
        type = lib.types.nullOr lib.types.numbers.nonnegative;
        default = null;
        description = "Sensitivity in thin mode; null keeps `base`.";
      };
      wide = lib.mkOption {
        type = lib.types.nullOr lib.types.numbers.nonnegative;
        default = null;
        description = "Sensitivity in wide mode; null keeps `base`.";
      };
      tall = lib.mkOption {
        type = lib.types.nullOr lib.types.numbers.nonnegative;
        default = null;
        description = ''
          Sensitivity in tall mode; null keeps `base`. Tall wants a much lower
          value because a pixel of mouse motion covers far more angle on a
          16384px-tall render.
        '';
      };
      lowest = lib.mkOption {
        type = lib.types.nullOr lib.types.numbers.nonnegative;
        default = null;
        description = ''
          Sensitivity in `lowest` mode; null keeps `base`. Unlike tall, this is
          not a mode you aim in, so leaving it alone is usually right.
        '';
      };
    };

    repeat_rate = lib.mkOption {
      type = lib.types.int;
      default = 40;
      description = ''
        Key repeats per second. Mostly here to speed up F3+F render-distance
        cycling; above 20Hz with a short delay, hotbar switching misbehaves.
      '';
    };
    repeat_delay = lib.mkOption {
      type = lib.types.int;
      default = 300;
      description = "Milliseconds a key must be held before repeating.";
    };
    confine_pointer = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Lock the pointer to the waywall window.";
    };

    layouts = let
      layoutOptions = {
        layout = lib.mkOption {
          type = lib.types.str;
          default = "us";
          description = "XKB layout name.";
        };
        variant = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "XKB variant.";
        };
        remaps = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = {};
          example = {
            m5 = "f3";
            capslock = "0";
          };
          description = ''
            Key/button remaps applied on top of the layout, as
            source = destination. Names come from waywall's keycode table.
          '';
        };
      };
    in {
      mcsr = layoutOptions;
      alt = layoutOptions;
    };

    panel = {
      frame = lib.mkOption {
        type = lib.types.enum ["full" "ecount" "none"];
        default = "full";
        description = ''
          Which border to draw around the right-hand instrument cluster:
          `full` frames all of it, `ecount` frames only the eye counter, `none`
          draws no frame.

          This is a fixed choice rather than one that follows what is on screen,
          because waywall cannot report that. Mirrors expose only
          close/get_depth/set_depth and no API function reads pixel contents, so
          there is no way to tell "the profiler chart is up" from "that region of
          the game is blank" -- meaning a frame that hugs whichever widgets
          currently have something in them is not implementable.
        '';
      };
      pie = {
        x = lib.mkOption {
          type = lib.types.int;
          default = 1290;
        };
        y = lib.mkOption {
          type = lib.types.int;
          default = 380;
        };
        scale = lib.mkOption {
          type = lib.types.numbers.positive;
          default = 0.75;
          description = ''
            Pie chart magnification, where scale 1 means a 420x423 destination.
            The height exceeds the 178px source deliberately: the game draws the
            chart as a squashed ellipse, and the stretch rounds it back out.
          '';
        };
      };
      percent = {
        x = lib.mkOption {
          type = lib.types.int;
          default = 1365;
        };
        y = lib.mkOption {
          type = lib.types.int;
          default = 730;
        };
        scale = lib.mkOption {
          type = lib.types.numbers.positive;
          default = 5.0;
          description = "Magnification of the two percentage labels (33x25 source).";
        };
        matchText = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Colour the percentages like `colors.text` instead of like the pie
            slice each one belongs to.
          '';
        };
      };
      ecount = {
        x = lib.mkOption {
          type = lib.types.int;
          default = 1300;
        };
        y = lib.mkOption {
          type = lib.types.int;
          default = 240;
        };
        scale = lib.mkOption {
          type = lib.types.numbers.positive;
          default = 5.0;
          description = "Magnification of the F3 ender-eye counter.";
        };
        showChunkCache = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Widen the source rect to include the chunk-cache line above E:.";
        };
      };
    };

    measure = {
      x = lib.mkOption {
        type = lib.types.int;
        default = 16;
      };
      y = lib.mkOption {
        type = lib.types.int;
        default = 333;
      };
      width = lib.mkOption {
        type = lib.types.ints.positive;
        default = 736;
        description = ''
          Boat-eye window size. Keep this 16:9 if `overlay` was authored on a
          16:9 canvas, since the overlay is drawn into exactly this rectangle
          and any aspect mismatch shifts the pixel ruler off the pixels.
        '';
      };
      height = lib.mkOption {
        type = lib.types.ints.positive;
        default = 414;
      };
      srcWidth = lib.mkOption {
        type = lib.types.ints.positive;
        default = 60;
        description = ''
          Width, in tall-render pixels, of the slice magnified into the boat-eye
          window. This is what sets the scale of the pixel ruler in `overlay`,
          so it is not a free choice: for one ruler cell to mean one render
          pixel, it must be

            canvas.width / (ruler span in px / number of cells)

          e.g. a ruler of 18 cells spanning 1152px of a 1920px canvas is 64px
          per cell, so this must be 30. Get it wrong and the ruler is a
          decoration that reads the wrong number of pixels.
        '';
      };
      srcHeight = lib.mkOption {
        type = lib.types.ints.positive;
        default = 580;
        description = "Height of the magnified slice, in tall-render pixels.";
      };
      overlay = lib.mkOption {
        type = lib.types.path;
        description = ''
          Pixel-ruler PNG drawn over the boat-eye window, e.g. from an overlay
          generator. Authored at the same aspect ratio as width x height.
        '';
      };
    };

    ninb = {
      anchor = lib.mkOption {
        type = lib.types.str;
        default = "topright";
        description = "Corner or edge Ninjabrain-Bot is pinned to.";
      };
      opacity = lib.mkOption {
        type = lib.types.numbers.between 0.0 1.0;
        default = 1.0;
        description = ''
          Ninjabrain-Bot window alpha. Needs compositor support for
          alpha_modifier_v1, otherwise ignored.
        '';
      };
      command = lib.mkOption {
        type = lib.types.str;
        default = "ninjabrain-bot";
        description = ''
          Command run inside waywall to start Ninjabrain-Bot. Running it as a
          waywall client is what lets it see clipboard updates from the game
          without being focused.
        '';
      };
      process = lib.mkOption {
        type = lib.types.str;
        default = "ninjabrain-bot";
        description = "pgrep -f pattern used to detect an already-running bot.";
      };
    };

    cps = {
      toggleCommand = lib.mkOption {
        type = lib.types.str;
        default = "systemctl --user is-active --quiet cps-overlay && systemctl --user stop cps-overlay || systemctl --user start cps-overlay";
        description = ''
          Shell command that starts the clicks-per-second overlay if it is not
          running and stops it if it is.

          This must start the overlay against the *host* compositor, not inside
          waywall. waywall overwrites its own WAYLAND_DISPLAY with its nested
          socket (waywall/main.c), so anything spawned with `waywall.exec` talks
          to waywall -- which implements no wlr-layer-shell, leaving a
          layer-shell client with no protocol to bind and nothing on screen. A
          systemd user unit is the reliable route: its environment still has the
          host display, and being a host client is also what puts the counter
          above the waywall window instead of inside it.
        '';
      };
    };

    paceman = {
      enable = lib.mkEnableOption "a keybind that launches paceman-tracker";
      command = lib.mkOption {
        type = lib.types.str;
        default = "paceman-tracker --nogui";
      };
      process = lib.mkOption {
        type = lib.types.str;
        default = "paceman-tracker";
      };
    };

    resizeAnimation = {
      enable = lib.mkEnableOption ''
        publishing the active resolution to a file so the OBS resize-animation
        script can tween the capture transform. Costs one frame (17ms) per
        resize, which is what gives OBS time to see the change before the game
        actually resizes
      '';
      stateFile = lib.mkOption {
        type = lib.types.str;
        default = "${config.home.homeDirectory}/.waywall_state";
        defaultText = lib.literalExpression "\"\${config.home.homeDirectory}/.waywall_state\"";
        description = "Path the active resolution is written to.";
      };
    };

    # Waywall action specs. A `*-` prefix makes the bind fire regardless of
    # which other modifiers happen to be held, which is what you want for
    # resolution toggles: they should still work mid-sprint with shift down.
    keys = lib.mapAttrs (name: default:
      lib.mkOption {
        type = lib.types.str;
        inherit default;
        description = "Keybind for ${name}.";
      }) {
      thin = "*-m4";
      wide = "*-shift-m4";
      tall = "*-f1";
      lowest = "*-ctrl-4";
      switch_layout = "*-ctrl-6";
      ninbot = "*-ctrl-k";
      cps = "*-ctrl-7";
      crosshair = "*-ctrl-8";
      paceman = "*-ctrl-p";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [cfg.package];

    assertions = [
      {
        assertion = let
          canvasAspect = cfg.canvas.width * cfg.measure.height;
          measureAspect = cfg.canvas.height * cfg.measure.width;
          slack = cfg.canvas.width * cfg.canvas.height / 100;
        in
          canvasAspect > measureAspect - slack && canvasAspect < measureAspect + slack;
        message = ''
          programs.waywall.measure width x height (${toString cfg.measure.width}x${toString cfg.measure.height})
          is not the same aspect ratio as the canvas
          (${toString cfg.canvas.width}x${toString cfg.canvas.height}). Overlay
          generators author the pixel ruler on a full canvas, so a mismatch
          stretches the ruler off the pixels it is meant to mark.
        '';
      }
    ];

    xdg.configFile."waywall/init.lua".text = initLua;
  };
}
