#!/usr/bin/env python3
"""Generate waywall overlay assets (window borders, crosshair dot).

Reads a JSON spec on stdin and writes PNGs into the directory given as argv[1].
Invoked from nix/lib/assets.nix; the spec is built there from the home-manager
module's options so every colour and coordinate traces back to Nix.

Spec shape:

    {
      "canvas":    {"w": 1920, "h": 1080},
      "border":    {"color": "#7aa2f7", "width": 3, "radius": 18, "opacity": 1.0},
      "crosshair": {"color": "#f7768e", "size": 9, "opacity": 0.9},
      "images":    {
        "frame_thin": {
          "rects": [ {"x":.., "y":.., "w":.., "h":.., "mask": true} ],
          "fills": [ {"outer": {...}, "inner": {...}} ]
        },
        ...
      }
    }

Each entry in "images" becomes one transparent canvas-sized PNG. Its "rects" are
rounded outlines; "mask" on a rect additionally paints out the square corners it
leaves poking past the rounded path. Its "fills" paint "outer" solid except for a
rounded hole at "inner", which is how the unwanted part of a viewport is hidden.
"""

import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw


def rgba(hex_color: str, opacity: float) -> tuple[int, int, int, int]:
    """#rgb / #rrggbb / #rrggbbaa -> RGBA tuple, scaled by `opacity`."""
    s = hex_color.lstrip("#")
    if len(s) == 3:
        s = "".join(c * 2 for c in s)
    if len(s) == 6:
        s += "ff"
    if len(s) != 8:
        raise ValueError(f"bad colour {hex_color!r}")
    r, g, b, a = (int(s[i : i + 2], 16) for i in (0, 2, 4, 6))
    return (r, g, b, round(a * opacity))


def geometry(rect: dict, width: int, radius: int):
    """Inset stroke box for `rect`, plus a radius Pillow will accept.

    Pillow strokes rounded_rectangle centred on the path, so a width-N stroke on
    the exact rectangle would spill N/2 pixels outward -- over the game window on
    one side and onto the background on the other. Insetting by half the width
    keeps the whole stroke inside the rect, which matters because these rects are
    the game viewport: any spill covers pixels the runner is reading.
    """
    inset = width / 2
    box = (
        rect["x"] + inset,
        rect["y"] + inset,
        rect["x"] + rect["w"] - 1 - inset,
        rect["y"] + rect["h"] - 1 - inset,
    )

    # A radius larger than half the shorter side makes Pillow raise; clamp it so
    # narrow rects (the 340px-wide thin viewport) degrade to a stadium shape
    # rather than failing the build.
    r = min(radius, int(min(box[2] - box[0], box[3] - box[1]) / 2))
    return box, max(r, 0)


def mask_corners(img: Image.Image, rect: dict, fill, width: int, radius: int) -> None:
    """Paint over the square corners of `rect` that fall outside the rounded path.

    Minecraft renders a rectangle, so a rounded border alone leaves a sliver of
    game visible past each corner. Filling the four wedges between the rect and
    the rounded path with the background colour is what actually makes the corner
    look round. Only the corners are ever touched: a rounded rectangle's straight
    edges are flush with the rect it is inscribed in.

    This assumes the waywall background is a solid colour. With a background
    image the wedges would read as four flat patches instead.
    """
    box, r = geometry(rect, width, radius)
    if r <= 0:
        return

    w, h = rect["w"], rect["h"]

    layer = Image.new("RGBA", (w, h), fill)
    # 255 keeps the pixel, 0 drops it -- so punching the rounded interior out of
    # an all-keep mask leaves exactly the corner wedges behind. The radius is
    # grown by half the stroke width so the wedges reach the stroke's outer edge;
    # the stroke is drawn afterwards and covers the seam.
    keep = Image.new("L", (w, h), 255)
    ImageDraw.Draw(keep).rounded_rectangle(
        (box[0] - rect["x"], box[1] - rect["y"], box[2] - rect["x"], box[3] - rect["y"]),
        radius=r + math.ceil(width / 2),
        fill=0,
    )
    layer.putalpha(keep)

    img.alpha_composite(layer, (rect["x"], rect["y"]))


def outline(draw: ImageDraw.ImageDraw, rect: dict, color, width: int, radius: int) -> None:
    box, r = geometry(rect, width, radius)
    draw.rounded_rectangle(box, radius=r, outline=color, width=width)


def fill_around(img: Image.Image, fill: dict, colour, width: int, radius: int) -> None:
    """Fill `fill["outer"]` opaquely, minus a rounded hole at `fill["inner"]`.

    Used to hide the part of the game that is not being shown. In `lowest` mode
    the instance renders at full canvas height while only a shorter mirrored slice
    of it is wanted on screen, so the strips of the real viewport above and below
    that slice have to be painted out -- otherwise the scene continues past the
    border and the mirror looks like a rectangle drawn on top of the game.
    """
    outer, inner = fill["outer"], fill["inner"]

    layer = Image.new("RGBA", (outer["w"], outer["h"]), colour)

    box, r = geometry(inner, width, radius)
    keep = Image.new("L", (outer["w"], outer["h"]), 255)
    ImageDraw.Draw(keep).rounded_rectangle(
        (
            box[0] - outer["x"],
            box[1] - outer["y"],
            box[2] - outer["x"],
            box[3] - outer["y"],
        ),
        radius=r,
        fill=0,
    )
    layer.putalpha(keep)

    img.alpha_composite(layer, (outer["x"], outer["y"]))


def main() -> None:
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)

    spec = json.load(sys.stdin)
    canvas = spec["canvas"]
    border = spec["border"]

    border_color = rgba(border["color"], border.get("opacity", 1.0))

    corner_fill = rgba(border["cornerFill"], 1.0) if border.get("cornerFill") else None

    for name, image in spec["images"].items():
        rects = image.get("rects", [])
        fills = image.get("fills", [])

        img = Image.new("RGBA", (canvas["w"], canvas["h"]), (0, 0, 0, 0))

        def w_of(rect):
            return int(rect.get("width", border["width"]))

        def r_of(rect):
            return int(rect.get("radius", border["radius"]))

        # Large fills first, then corner wedges, then strokes: each stage paints
        # over the one before, and a stroke must never be covered by a later
        # rect's mask.
        if corner_fill:
            for fill in fills:
                fill_around(img, fill, corner_fill, w_of(fill["inner"]), r_of(fill["inner"]))
            for rect in rects:
                if rect.get("mask", False):
                    mask_corners(img, rect, corner_fill, w_of(rect), r_of(rect))

        draw = ImageDraw.Draw(img)
        for rect in rects:
            outline(draw, rect, border_color, w_of(rect), r_of(rect))
        img.save(out / f"{name}.png")

    # Crosshair: a filled dot with a 1px darker rim so it stays visible against
    # both sky and stone. Drawn at 8x and downsampled -- waywall scales images
    # with GL_LINEAR, and a hard-edged 9px circle turns to mush when it does,
    # whereas a pre-antialiased one survives.
    cross = spec["crosshair"]
    size = int(cross["size"])
    scale = 8
    big = Image.new("RGBA", (size * scale, size * scale), (0, 0, 0, 0))
    bd = ImageDraw.Draw(big)
    bd.ellipse((0, 0, size * scale - 1, size * scale - 1), fill=rgba("#000000", 0.55))
    pad = scale
    bd.ellipse(
        (pad, pad, size * scale - 1 - pad, size * scale - 1 - pad),
        fill=rgba(cross["color"], cross.get("opacity", 1.0)),
    )
    big.resize((size, size), Image.LANCZOS).save(out / "crosshair.png")


if __name__ == "__main__":
    main()
