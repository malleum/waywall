# Declarative Ninjabrain-Bot configuration.
#
# Ninjabrain-Bot persists everything through the Java Preferences API, which on
# Linux means a flat XML map at ~/.java/.userPrefs/ninjabrainbot/prefs.xml. This
# module renders that file from Nix options so the calculator's sensitivity,
# sigmas and hotkeys are version-controlled rather than clicked in once and lost
# on the next machine.
#
# Option names deliberately match the preference keys 1:1, so anything not
# modelled here can still be set through `settings.extra`. The hotkey encoding
# and the enum orderings were worked out by
# <https://tangled.org/althaea.zone/ninjabrain-bot-nix>; see nix/lib/ninb-theme.nix
# for the theme string format.
{self}: {
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.programs.ninjabrain-bot;

  ninbTheme = import ../lib/ninb-theme.nix {inherit lib;};

  # jnativehook modifier masks (com.1stleg:jnativehook:2.0.2 constants).
  modifierMasks = {
    SHIFT_L = 1;
    CTRL_L = 2;
    META_L = 4;
    ALT_L = 8;
    SHIFT_R = 16;
    CTRL_R = 32;
    META_R = 64;
    ALT_R = 128;
  };

  # jnativehook key locations. A hotkey is stored as `key | location << 16`.
  locationValues = {
    UNKNOWN = 0;
    STANDARD = 1;
    LEFT = 2;
    RIGHT = 3;
    NUMPAD = 4;
  };

  # Enum-valued preferences are stored as the index of the value in
  # Ninjabrain-Bot's own enum declaration order.
  enums = {
    size = ["small" "medium" "large"];
    stronghold_display_type = ["fourfour" "eighteight" "chunk"];
    view = ["basic" "detailed"];
    mc_version = ["pre_119" "post_119"];
    aa_toggle_type = ["automatic" "hotkey"];
    default_boat_type = ["gray" "blue" "green"];
    angle_adjustment_type = ["subpixel" "tall" "custom"];
    angle_adjustment_display_type = ["angle_change" "increments"];
  };

  hotkeyType = lib.types.submodule {
    options = {
      key = lib.mkOption {
        type = lib.types.int;
        example = 19;
        description = ''
          Raw jnativehook keycode -- the value of the matching `VC_*` constant
          in <https://javadoc.io/doc/com.1stleg/jnativehook/2.0.2/constant-values.html>.
          `VC_R` is 19, so "R" is 19.
        '';
      };
      location = lib.mkOption {
        type = lib.types.enum (builtins.attrNames locationValues);
        default = "UNKNOWN";
        description = ''
          Which physical instance of the key. Only matters for keys that exist
          twice (numpad digits, left/right modifiers); `UNKNOWN` matches the
          main block, which is almost always what you want.
        '';
      };
      modifiers = lib.mkOption {
        type = lib.types.listOf (lib.types.enum (builtins.attrNames modifierMasks));
        default = [];
        example = ["CTRL_L"];
        description = "Modifiers held alongside the key.";
      };
    };
  };

  mkHotkey = lib.mkOption {
    type = lib.types.nullOr hotkeyType;
    default = null;
    description = "Global hotkey, or null to leave unbound.";
  };

  # A hotkey option expands into the two preference keys the bot actually reads.
  expandHotkey = name: value: {
    "${name}_code" = value.key + locationValues.${value.location} * 65536;
    "${name}_modifier" =
      builtins.foldl' (acc: m: acc + modifierMasks.${m}) 0 value.modifiers;
  };

  enumIndex = name: value:
    lib.lists.findFirstIndex (x: x == value) (throw "ninjabrain-bot: ${value} is not a valid ${name}") enums.${name};

  # Numbers go through toJSON, not toString: toString rounds floats to six
  # decimal places, which would turn a sensitivity of 0.02291165 into
  # 0.022912 and skew every eye throw. toJSON emits full precision in a form
  # Java's Double.parseDouble accepts.
  renderValue = v:
    if builtins.isBool v
    then
      (
        if v
        then "true"
        else "false"
      )
    else if builtins.isString v
    then v
    else builtins.toJSON v;

  settings =
    (lib.filterAttrs (n: v: v != null && n != "extra" && !(lib.hasPrefix "hotkey_" n)) cfg.settings)
    // (lib.mapAttrs (name: _: enumIndex name cfg.settings.${name}) enums)
    // (lib.concatMapAttrs (
        name: value:
          if lib.hasPrefix "hotkey_" name && value != null
          then expandHotkey name value
          else {}
      )
      cfg.settings)
    // {
      theme =
        if cfg.stylix
        then -1
        else cfg.settings.theme;
      custom_themes = lib.optionalString cfg.stylix (ninbTheme.mkTheme cfg.base16Scheme);
      custom_themes_names = lib.optionalString cfg.stylix "Stylix";
    }
    // cfg.settings.extra;

  prefsXml = ''
    <?xml version="1.0" encoding="UTF-8" standalone="no"?>
    <!DOCTYPE map SYSTEM "http://java.sun.com/dtd/preferences.dtd">
    <map MAP_XML_VERSION="1.0">
    ${lib.concatLines (lib.mapAttrsToList (
        k: v: ''<entry key="${k}" value="${lib.escapeXML (renderValue v)}"/>''
      )
      settings)}</map>
  '';
in {
  options.programs.ninjabrain-bot = {
    enable = lib.mkEnableOption "Ninjabrain-Bot with a declarative preferences file";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.ninjabrainbot;
      defaultText = lib.literalExpression "waywall.packages.\${system}.ninjabrainbot";
      description = "Ninjabrain-Bot package to install.";
    };

    stylix = lib.mkEnableOption ''
      a generated custom theme built from `base16Scheme` instead of one of
      Ninjabrain-Bot's built-in themes
    '';

    base16Scheme = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = ''
        base16 palette used when `stylix` is enabled. Pass
        `config.stylix.base16Scheme` here.
      '';
    };

    settings = lib.mkOption {
      description = "Contents of ~/.java/.userPrefs/ninjabrainbot/prefs.xml.";
      default = {};
      type = lib.types.submodule {
        options =
          {
            extra = lib.mkOption {
              type = lib.types.attrsOf (lib.types.oneOf [lib.types.str lib.types.int lib.types.bool lib.types.float]);
              default = {};
              description = ''
                Escape hatch for preference keys this module does not model.
                Merged last, so it overrides everything above.
              '';
            };

            settings_version = lib.mkOption {
              type = lib.types.int;
              default = 3;
              description = "Preferences schema version the bot migrates from.";
            };

            theme = lib.mkOption {
              type = lib.types.int;
              default = 1;
              description = ''
                Built-in theme index. Ignored when `stylix` is enabled, which
                forces -1 (the first custom theme).
              '';
            };

            language_v2 = lib.mkOption {
              type = lib.types.str;
              default = "en-US";
              description = "UI language, or \"\" to follow the system locale.";
            };

            window_x = lib.mkOption {
              type = lib.types.int;
              default = 100;
            };
            window_y = lib.mkOption {
              type = lib.types.int;
              default = 100;
            };

            # Measurement precision. `sensitivity` is the in-game mouse
            # sensitivity the bot uses to convert pixel counts into angles, so
            # it must match Minecraft's slider exactly or every throw is
            # skewed. The sigmas are the assumed standard deviation of the
            # runner's aim, per throw type.
            sensitivity = lib.mkOption {
              type = lib.types.float;
              default = 0.012727597;
            };
            sensitivity_manual = lib.mkOption {
              type = lib.types.float;
              default = 0.4341732;
            };
            sigma = lib.mkOption {
              type = lib.types.float;
              default = 0.1;
            };
            sigma_alt = lib.mkOption {
              type = lib.types.float;
              default = 0.1;
            };
            sigma_manual = lib.mkOption {
              type = lib.types.float;
              default = 0.03;
            };
            sigma_boat = lib.mkOption {
              type = lib.types.float;
              default = 0.001;
            };
            boat_error = lib.mkOption {
              type = lib.types.float;
              default = 0.03;
            };
            crosshair_correction = lib.mkOption {
              type = lib.types.float;
              default = 0.0;
            };
            custom_adjustment = lib.mkOption {
              type = lib.types.float;
              default = 0.01;
            };
            resolution_height = lib.mkOption {
              type = lib.types.int;
              default = 16384;
              description = "Render height used for tall-mode angle adjustment.";
            };
            overlay_hide_delay = lib.mkOption {
              type = lib.types.float;
              default = 30.0;
            };
          }
          // lib.mapAttrs (_: values:
            lib.mkOption {
              type = lib.types.enum values;
              default = builtins.head values;
              description = "One of: ${lib.concatStringsSep ", " values}.";
            })
          enums
          // lib.genAttrs [
            "hotkey_increment"
            "hotkey_decrement"
            "hotkey_reset"
            "hotkey_undo"
            "hotkey_redo"
            "hotkey_minimize"
            "hotkey_alt_std"
            "hotkey_lock"
            "hotkey_boat"
            "hotkey_mod_360"
            "hotkey_toggle_aa_mode"
          ] (_: mkHotkey)
          // lib.mapAttrs (_: default:
            lib.mkOption {
              type = lib.types.bool;
              inherit default;
            }) {
            all_advancements = false;
            alt_clipboard_reader = false;
            always_on_top = true;
            auto_reset = false;
            auto_reset_on_instance_change = false;
            check_for_updates = true;
            color_negative_coords = false;
            combined_offset_information_enabled = true;
            direction_help_enabled = false;
            enable_http_server = false;
            mismeasure_warning_enabled = false;
            one_dot_twenty_plus_aa = false;
            overlay_auto_hide = false;
            overlay_lock_hide = false;
            portal_linking_warning_enabled = true;
            save_state = true;
            show_angle_errors = false;
            show_angle_updates = false;
            show_nether_coords = true;
            translucent = false;
            use_adv_statistics = true;
            use_alt_std = false;
            use_obs_overlay = false;
            use_precise_angle = false;
          };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [cfg.package];

    # `force` is required, not merely convenient: Ninjabrain-Bot rewrites its
    # own preferences file on exit, which replaces home-manager's symlink with
    # a regular file and makes the next activation refuse to clobber it.
    home.file.".java/.userPrefs/ninjabrainbot/prefs.xml" = {
      force = true;
      text = prefsXml;
    };
  };
}
