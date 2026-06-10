#!/usr/bin/env python3
"""Blend the pywal palette with each terminal's base theme and write its colors.

Pywal normally blasts its full palette at every open terminal via OSC escape
sequences. Instead we want only a gentle tint: mostly the terminal's own base
theme, nudged a little toward the wallpaper colours. Each terminal live-reloads
the generated theme file, so it overrides the raw pywal sequence.

Tint strength is the fraction of pywal taken (0.0 = pure base, 1.0 = pure
pywal). Override with the TERMINAL_TINT env var or a single CLI arg.
"""

import json
import os
import sys
from pathlib import Path

# Fraction of the pywal colour to mix in (rest stays the base theme).
DEFAULT_TINT = 0.10

# Order of the 8 ANSI names against pywal color0..color7 / color8..color15.
ANSI = ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"]

HOME = Path.home()
CACHE = HOME / ".cache" / "wal" / "colors.json"


# Each base palette: bg, fg, then 8 normal + 8 bright in ANSI order.
# (alacritty is intentionally excluded: it keeps a static theme and lets the
#  swayfx-blurred wallpaper seep through via window opacity instead.)
ZENBURN = {  # foot's existing inline base
    "bg": "#222222", "fg": "#dcdccc",
    "normal": ["#222222", "#cc9393", "#7f9f7f", "#d0bf8f",
               "#6ca0a3", "#dc8cc3", "#93e0e3", "#dcdccc"],
    "bright": ["#666666", "#dca3a3", "#bfebbf", "#f0dfaf",
               "#8cd0d3", "#fcace3", "#b3ffff", "#ffffff"],
}

KITTY_DEFAULT = {  # kitty's built-in palette (config is empty)
    "bg": "#000000", "fg": "#dddddd",
    "normal": ["#000000", "#cc0403", "#19cb00", "#cecb00",
               "#0d73cc", "#cb1ed1", "#0dcdcd", "#dddddd"],
    "bright": ["#767676", "#f2201f", "#23fd00", "#fffd00",
               "#1a8fff", "#fd28ff", "#14ffff", "#ffffff"],
}


def hex_to_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def rgb_to_hex(rgb, hashed=True):
    s = "{:02x}{:02x}{:02x}".format(*(max(0, min(255, round(c))) for c in rgb))
    return "#" + s if hashed else s


def blend(base_hex, pywal_hex, t, hashed=True):
    b, p = hex_to_rgb(base_hex), hex_to_rgb(pywal_hex)
    return rgb_to_hex(tuple(b[i] * (1 - t) + p[i] * t for i in range(3)), hashed)


def mix(base, pw, t, hashed=True):
    """Return tinted (bg, fg, normal[8], bright[8]) for a base palette."""
    special, colors = pw["special"], pw["colors"]
    bg = blend(base["bg"], special["background"], t, hashed)
    fg = blend(base["fg"], special["foreground"], t, hashed)
    normal = [blend(base["normal"][i], colors[f"color{i}"], t, hashed)
              for i in range(8)]
    bright = [blend(base["bright"][i], colors[f"color{i + 8}"], t, hashed)
              for i in range(8)]
    return bg, fg, normal, bright


def write_foot(pw, t):
    bg, fg, normal, bright = mix(ZENBURN, pw, t, hashed=False)
    lines = [f"# Zenburn tinted with pywal ({t:.0%} pywal)", "[colors]",
             f"foreground={fg}", f"background={bg}"]
    for i, c in enumerate(normal):
        lines.append(f"regular{i}={c}")
    for i, c in enumerate(bright):
        lines.append(f"bright{i}={c}")
    (HOME / ".config/foot/theme.ini").write_text("\n".join(lines) + "\n")


def write_kitty(pw, t):
    bg, fg, normal, bright = mix(KITTY_DEFAULT, pw, t, hashed=True)
    lines = [f"# kitty default tinted with pywal ({t:.0%} pywal)",
             f"foreground {fg}", f"background {bg}"]
    for i, c in enumerate(normal):
        lines.append(f"color{i} {c}")
    for i, c in enumerate(bright):
        lines.append(f"color{i + 8} {c}")
    (HOME / ".config/kitty/theme.conf").write_text("\n".join(lines) + "\n")


def main():
    if len(sys.argv) > 1:
        tint = float(sys.argv[1])
    else:
        tint = float(os.environ.get("TERMINAL_TINT", DEFAULT_TINT))

    pw = json.loads(CACHE.read_text())
    write_foot(pw, tint)
    write_kitty(pw, tint)


if __name__ == "__main__":
    main()
