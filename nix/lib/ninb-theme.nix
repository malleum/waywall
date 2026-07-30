# base16 palette -> Ninjabrain-Bot custom-theme string.
#
# Ninjabrain-Bot stores custom themes in its preferences as a run of
# `<tag><4 chars>` groups, where the tag names a UI element and the four
# characters are the colour packed 6 bits at a time into printable ASCII
# starting at '0' (ThemeSerializer.java: `to_char(i) = '0' + (i & 0x3f)`,
# most-significant group first).
#
# This is a Nix port of the Rust serializer in
# <https://tangled.org/althaea.zone/ninjabrain-bot-nix>, which is where the tag
# -> element mapping below comes from. Reimplementing it here keeps the flake
# free of a Rust toolchain (crane + fenix) just to emit 76 characters of text.
{lib}: let
  chars = "0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmno";

  toChar = i: builtins.substring i 1 chars;

  hexDigits = {
    "0" = 0;
    "1" = 1;
    "2" = 2;
    "3" = 3;
    "4" = 4;
    "5" = 5;
    "6" = 6;
    "7" = 7;
    "8" = 8;
    "9" = 9;
    a = 10;
    b = 11;
    c = 12;
    d = 13;
    e = 14;
    f = 15;
    A = 10;
    B = 11;
    C = 12;
    D = 13;
    E = 14;
    F = 15;
  };

  # "1a1b26" -> 0x1a1b26. Six digits exactly; base16 schemes never carry alpha.
  parseHex = str: let
    s = lib.removePrefix "#" str;
    digits = lib.stringToCharacters s;
  in
    assert lib.assertMsg (builtins.stringLength s == 6) "ninb-theme: expected a 6-digit hex colour, got ${str}";
      builtins.foldl' (acc: c: acc * 16 + hexDigits.${c}) 0 digits;

  # 24-bit value -> four 6-bit characters, most significant first.
  serializeColour = hex: let
    v = parseHex hex;
    group = shift: toChar (lib.mod (v / shift) 64);
  in
    group 262144 + group 4096 + group 64 + group 1;

  tag = t: colour: t + serializeColour colour;
in {
  # `colors` is a base16 attrset (stylix's `config.stylix.base16Scheme`, or
  # anything with the same base00..base0F keys, with or without a leading #).
  mkTheme = colors:
    lib.concatStrings [
      (tag "a" colors.base00) # title bar
      (tag "b" colors.base01) # header background
      (tag "c" colors.base01) # result background
      (tag "d" colors.base01) # throws background
      (tag "e" colors.base00) # dividers
      (tag "f" colors.base00) # darker dividers
      (tag "h" colors.base05) # foreground
      (tag "n" colors.base05) # title foreground
      (tag "k" colors.base05) # foreground (throws table)
      (tag "i" colors.base05) # divine text
      (tag "j" colors.base04) # version text
      (tag "o" colors.base04) # table header text
      (tag "l" colors.base0B) # "good" / positive delta
      (tag "m" colors.base08) # "bad" / negative delta
      (tag "r" colors.base0B) # 100% certainty
      (tag "q" colors.base0E) # 50% certainty
      (tag "p" colors.base08) # 0% certainty
    ];
}
