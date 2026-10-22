#!/usr/bin/env python3
"""Transient recording status overlay for sway/wlroots.

The overlay uses a wlr-layer-shell surface in the overlay layer, so it is
visible above fullscreen windows.  It is deliberately a short-lived process:
screen-record.sh waits for it to exit (and for the compositor to repaint)
before starting wf-recorder, so the overlay can never end up in the recording.

Usage:
    recording-overlay.py --mode countdown --seconds 3
    recording-overlay.py --mode message --icon "✓" --title "Recording saved" \
        --body "2026...--screen-recording.mkv" --accent "#a3be8c" --timeout-ms 4000

Set --mode message --timeout-ms 0 to leave it on screen until killed.
"""

import argparse
import re
import signal

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GtkLayerShell", "0.1")

from gi.repository import Gdk, GLib, Gtk, GtkLayerShell

try:
    import cairo
except ImportError:  # pragma: no cover - cairo is normally available with PyGObject
    cairo = None


CSS_TEMPLATE = """
window {
    background-color: transparent;
}

#overlay-card {
    background-color: rgba(24, 26, 32, 0.94);
    border: 2px solid {accent};
    border-radius: 14px;
    padding: 16px 26px 16px 22px;
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.55);
    min-width: 380px;
}

#overlay-icon {
    color: {accent};
    font-family: "JetBrainsMono Nerd Font", "DejaVu Sans", sans-serif;
    font-size: 30px;
}

#overlay-title {
    color: #eceff4;
    font-family: "JetBrainsMono Nerd Font", "DejaVu Sans", sans-serif;
    font-size: 21px;
    font-weight: 700;
}

#overlay-body {
    color: #d8dee9;
    font-family: "JetBrainsMono Nerd Font", "DejaVu Sans", sans-serif;
    font-size: 14px;
}
"""


def parse_args():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=("countdown", "message"), default="message")
    parser.add_argument("--seconds", type=int, default=3)
    parser.add_argument("--icon", default="●")
    parser.add_argument("--title", default="REC")
    parser.add_argument("--body", default="")
    parser.add_argument("--accent", default="#bf616a")
    parser.add_argument("--timeout-ms", type=int, default=0)
    return parser.parse_args()


def choose_monitor(window):
    """Put the overlay on the monitor the pointer is on, when possible."""
    display = Gdk.Display.get_default()
    if display is None:
        return

    monitor = None
    seat = display.get_default_seat()
    if seat is not None:
        pointer = seat.get_pointer()
        if pointer is not None:
            _, x, y = pointer.get_position()
            monitor = display.get_monitor_at_point(x, y)

    if monitor is None:
        monitor = display.get_primary_monitor()

    if monitor is not None:
        GtkLayerShell.set_monitor(window, monitor)


def main():
    args = parse_args()

    accent = args.accent
    if not re.fullmatch(r"#[0-9a-fA-F]{6}", accent):
        accent = "#bf616a"

    window = Gtk.Window()
    window.set_title("recording-overlay")
    window.set_decorated(False)
    window.set_resizable(False)
    window.set_skip_taskbar_hint(True)
    window.set_skip_pager_hint(True)
    window.set_accept_focus(False)
    window.set_focus_on_map(False)
    window.set_app_paintable(True)

    screen = window.get_screen()
    visual = screen.get_rgba_visual() if screen is not None else None
    if visual is not None:
        window.set_visual(visual)

    card = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=14)
    card.set_name("overlay-card")

    icon_label = Gtk.Label(label=args.icon)
    icon_label.set_name("overlay-icon")
    icon_label.set_valign(Gtk.Align.CENTER)

    text_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
    title_label = Gtk.Label(label=args.title)
    title_label.set_name("overlay-title")
    title_label.set_xalign(0.0)

    body_label = Gtk.Label(label=args.body)
    body_label.set_name("overlay-body")
    body_label.set_xalign(0.0)
    body_label.set_line_wrap(True)
    body_label.set_max_width_chars(60)
    body_label.set_visible(bool(args.body))

    text_box.pack_start(title_label, False, False, 0)
    text_box.pack_start(body_label, False, False, 0)

    card.pack_start(icon_label, False, False, 0)
    card.pack_start(text_box, True, True, 0)

    outer = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
    outer.set_halign(Gtk.Align.CENTER)
    outer.pack_start(card, False, False, 0)
    window.add(outer)

    css = CSS_TEMPLATE.replace("{accent}", accent).encode("utf-8")
    provider = Gtk.CssProvider()
    provider.load_from_data(css)
    Gtk.StyleContext.add_provider_for_screen(
        screen, provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
    )

    GtkLayerShell.init_for_window(window)
    GtkLayerShell.set_namespace(window, "recording-overlay")
    GtkLayerShell.set_layer(window, GtkLayerShell.Layer.OVERLAY)
    GtkLayerShell.set_anchor(window, GtkLayerShell.Edge.TOP, True)
    GtkLayerShell.set_anchor(window, GtkLayerShell.Edge.LEFT, True)
    GtkLayerShell.set_anchor(window, GtkLayerShell.Edge.RIGHT, True)
    GtkLayerShell.set_margin(window, GtkLayerShell.Edge.TOP, 36)
    GtkLayerShell.set_exclusive_zone(window, -1)
    GtkLayerShell.set_keyboard_mode(window, GtkLayerShell.KeyboardMode.NONE)
    choose_monitor(window)

    loop_running = True

    def quit_now(*_unused):
        nonlocal loop_running
        if loop_running:
            loop_running = False
            Gtk.main_quit()
        return False

    def on_destroy(*_unused):
        quit_now()
        return False

    window.connect("destroy", on_destroy)

    def set_body(text):
        body_label.set_text(text)
        body_label.set_visible(bool(text))

    if args.mode == "message":
        if args.timeout_ms > 0:
            GLib.timeout_add(args.timeout_ms, quit_now)
    else:
        remaining = max(1, args.seconds)
        set_body(f"Recording starts in {remaining}…")

        blink_on = True

        def blink():
            nonlocal blink_on
            blink_on = not blink_on
            icon_label.set_opacity(1.0 if blink_on else 0.25)
            return True

        def tick():
            nonlocal remaining
            remaining -= 1
            if remaining <= 0:
                set_body("Starting recorder…")
                GLib.timeout_add(250, quit_now)
                return False
            set_body(f"Recording starts in {remaining}…")
            return True

        GLib.timeout_add(500, blink)
        GLib.timeout_add(1000, tick)

    for sig in (signal.SIGINT, signal.SIGTERM):
        signal.signal(sig, quit_now)

    window.show_all()

    # The overlay is purely informational: do not intercept clicks.
    if cairo is not None:
        try:
            window.input_shape_combine_region(cairo.Region())
        except Exception:
            try:
                gdk_window = window.get_window()
                if gdk_window is not None:
                    gdk_window.input_shape_combine_region(cairo.Region(), 0, 0)
            except Exception:
                pass

    Gtk.main()

    loop_running = False
    try:
        window.destroy()
    except Exception:
        pass

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
