#!/usr/bin/env python3
"""Wallpaper carousel (coverflow, endless rotation).

Usage: carousel.py CURRENT_PATH IMG1 IMG2 ...
Keys : Left/Right (or h/l, Up/Down) rotate, mouse wheel rotates, click a side card to bring it forward,
       Enter / click on the centre card applies it, Escape (or q / losing focus) cancels.
The wallpaper is previewed live once the carousel stops moving; cancelling restores the original one.
"""
import hashlib
import math
import os
import subprocess
import sys

STATE = os.path.expanduser("~/.config/wallpapers/script/.current")
CACHE = os.path.expanduser("~/.cache/wallpaper-carousel")

W, H = 1180, 450
CARD_W, CARD_H = 520, 293
CY = 36 + CARD_H / 2            # vertical centre of the cards
THUMB_W, THUMB_H = 640, 360     # thumbnails are loaded at this size
VISIBLE = 3.2                   # cards further than this from the centre are not drawn

# Catppuccin Mocha
BASE = (0.118, 0.118, 0.180)
SURFACE0 = (0.192, 0.196, 0.267)
LAVENDER = (0.706, 0.745, 0.996)
TEXT = (0.804, 0.839, 0.957)
SUBTEXT = (0.651, 0.678, 0.784)
OVERLAY0 = (0.424, 0.439, 0.525)


# ---------------------------------------------------------------- pure geometry (easy to test)
def wrap_distance(i, pos, n):
    """Signed distance from the centre to card i on a ring of n cards (in [-n/2, n/2))."""
    return (i - pos + n / 2.0) % n - n / 2.0


def x_offset(ad):
    a = min(ad, 1.0)
    b = min(max(ad - 1.0, 0.0), 1.0)
    c = max(ad - 2.0, 0.0)
    return CARD_W * (0.60 * a + 0.26 * b + 0.16 * c)


def card_scale(ad):
    return max(0.40, 1.0 - 0.22 * ad)


def card_alpha(ad):
    return max(0.0, 1.0 - 0.32 * ad)


def rrect(cr, x, y, w, h, r):
    cr.new_sub_path()
    cr.arc(x + w - r, y + r, r, -math.pi / 2, 0)
    cr.arc(x + w - r, y + h - r, r, 0, math.pi / 2)
    cr.arc(x + r, y + h - r, r, math.pi / 2, math.pi)
    cr.arc(x + r, y + r, r, math.pi, 3 * math.pi / 2)
    cr.close_path()


# ---------------------------------------------------------------- thumbnail cache (small JPEGs on disk)
def thumb_path(p):
    try:
        st = os.stat(p)
        key = "%s|%d|%d" % (p, st.st_mtime_ns, st.st_size)
    except OSError:
        key = p
    return os.path.join(CACHE, hashlib.sha1(key.encode()).hexdigest()[:20] + ".jpg")


def ensure_thumb(p, GdkPixbuf):
    """Return the path of a small JPEG for image p (created once); fall back to the original on error."""
    tp = thumb_path(p)
    if os.path.exists(tp):
        return tp
    try:
        os.makedirs(CACHE, exist_ok=True)
        pb = GdkPixbuf.Pixbuf.new_from_file_at_scale(p, THUMB_W, THUMB_H, True)
        tmp = tp + ".tmp"
        pb.savev(tmp, "jpeg", ["quality"], ["88"])
        os.replace(tmp, tp)
        return tp
    except Exception:
        return p


# ---------------------------------------------------------------- GUI
def main():
    try:
        import gi
        gi.require_version("Gtk", "3.0")
        gi.require_version("Gdk", "3.0")
        from gi.repository import Gtk, Gdk, GLib, GdkPixbuf
        import cairo
    except (ImportError, ValueError):
        sys.exit(99)                      # lets wallpaper.sh fall back to rofi

    if len(sys.argv) > 1 and sys.argv[1] == "--warm":     # pre-build all thumbnails, no window
        for img in sys.argv[2:]:
            ensure_thumb(img, GdkPixbuf)
        return

    original = sys.argv[1] if len(sys.argv) > 1 else ""
    paths = sys.argv[2:]
    n = len(paths)
    if n == 0:
        sys.exit(1)
    start = paths.index(original) if original in paths else 0

    def feh(path, wait=False):
        cmd = ["feh", "--no-fehbg", "--bg-fill", path]
        if wait:
            subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        else:
            subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    class Carousel(Gtk.Window):
        def __init__(self):
            super().__init__(type=Gtk.WindowType.TOPLEVEL)
            self.set_title("Wallpapers")
            self.set_wmclass("wallpaper-carousel", "wallpaper-carousel")
            self.set_decorated(False)
            self.set_resizable(False)
            self.set_type_hint(Gdk.WindowTypeHint.DIALOG)
            self.set_default_size(W, H)
            self.set_position(Gtk.WindowPosition.CENTER)
            self.set_app_paintable(True)
            visual = self.get_screen().get_rgba_visual()
            if visual:
                self.set_visual(visual)

            self.target = float(start)
            self.pos = float(start)
            self.anim = 0
            self.loader = 0
            self.preview_timer = 0
            self.cache = {}
            self.failed = set()
            self.shown = original          # what is currently on the desktop
            self.had_focus = False
            self.scroll_acc = 0.0

            self.add_events(Gdk.EventMask.SCROLL_MASK | Gdk.EventMask.BUTTON_PRESS_MASK
                            | Gdk.EventMask.KEY_PRESS_MASK)
            self.connect("draw", self.on_draw)
            self.connect("key-press-event", self.on_key)
            self.connect("scroll-event", self.on_scroll)
            self.connect("button-press-event", self.on_click)
            self.connect("focus-in-event", lambda *a: setattr(self, "had_focus", True) or False)
            self.connect("focus-out-event", self.on_focus_out)
            self.connect("destroy", Gtk.main_quit)

            # decode the visible cards first, so the very first frame is complete when the window appears
            for k in (0, 1, -1, 2, -2):
                j = (start + k) % n
                if j not in self.cache and j not in self.failed:
                    self.load(j)
            self.ensure_loader()
            self.show_all()
            self.present()

        # -- thumbnails
        def load(self, i):
            try:
                pb = GdkPixbuf.Pixbuf.new_from_file_at_scale(ensure_thumb(paths[i], GdkPixbuf), THUMB_W, THUMB_H, True)
                self.cache[i] = (Gdk.cairo_surface_create_from_pixbuf(pb, 1, None), pb.get_width(), pb.get_height())
            except Exception:
                self.failed.add(i)

        def load_next(self):
            c = int(round(self.target))
            for k in range(0, 5):
                for sgn in ((0,) if k == 0 else (-1, 1)):
                    i = (c + sgn * k) % n
                    if i not in self.cache and i not in self.failed:
                        self.load(i)
                        self.queue_draw()
                        return True
            self.loader = 0
            return False

        def ensure_loader(self):
            if not self.loader:
                self.loader = GLib.idle_add(self.load_next)

        # -- movement
        def current_index(self):
            return int(round(self.target)) % n

        def move(self, delta):
            self.target += delta
            if self.preview_timer:
                GLib.source_remove(self.preview_timer)
                self.preview_timer = 0
            if not self.anim:
                self.anim = GLib.timeout_add(16, self.tick)
            self.ensure_loader()

        def tick(self):
            diff = self.target - self.pos
            if abs(diff) < 0.002:
                self.pos = self.target
                self.anim = 0
                self.queue_draw()
                self.preview_timer = GLib.timeout_add(350, self.preview)
                return False
            self.pos += diff * 0.2
            self.queue_draw()
            return True

        def preview(self):
            self.preview_timer = 0
            p = paths[self.current_index()]
            if p != self.shown:
                feh(p)
                self.shown = p
            return False

        # -- finish
        def apply_and_quit(self):
            p = paths[self.current_index()]
            if p != self.shown:
                feh(p, wait=True)
            try:
                with open(STATE, "w") as f:
                    f.write(p + "\n")
            except OSError:
                pass
            Gtk.main_quit()

        def cancel(self):
            if original and self.shown != original:
                feh(original, wait=True)
            Gtk.main_quit()

        # -- events
        def on_key(self, w, ev):
            k = Gdk.keyval_name(ev.keyval)
            if k in ("Left", "h", "Up", "k"):
                self.move(-1)
            elif k in ("Right", "l", "Down", "j"):
                self.move(1)
            elif k in ("Return", "KP_Enter"):
                self.apply_and_quit()
            elif k in ("Escape", "q"):
                self.cancel()
            return True

        def on_scroll(self, w, ev):
            if ev.direction in (Gdk.ScrollDirection.UP, Gdk.ScrollDirection.LEFT):
                self.move(-1)
            elif ev.direction in (Gdk.ScrollDirection.DOWN, Gdk.ScrollDirection.RIGHT):
                self.move(1)
            elif ev.direction == Gdk.ScrollDirection.SMOOTH:
                ok, dx, dy = ev.get_scroll_deltas()
                self.scroll_acc += dx + dy
                while abs(self.scroll_acc) >= 1.0:
                    step = 1 if self.scroll_acc > 0 else -1
                    self.move(step)
                    self.scroll_acc -= step
            return True

        def on_click(self, w, ev):
            if ev.button != 1:
                return True
            if abs(ev.x - W / 2) <= CARD_W / 2 and abs(ev.y - CY) <= CARD_H / 2:
                self.apply_and_quit()
            elif ev.x < W / 2:
                self.move(-1)
            else:
                self.move(1)
            return True

        def on_focus_out(self, w, ev):
            if self.had_focus:
                GLib.timeout_add(150, self.cancel_if_unfocused)
            return False

        def cancel_if_unfocused(self):
            if not self.is_active():
                self.cancel()
            return False

        # -- drawing
        def on_draw(self, w, cr):
            cr.set_operator(cairo.OPERATOR_SOURCE)
            cr.set_source_rgba(0, 0, 0, 0)
            cr.paint()
            cr.set_operator(cairo.OPERATOR_OVER)
            rrect(cr, 0, 0, W, H, 16)
            cr.set_source_rgba(*BASE, 0.97)
            cr.fill()

            items = []
            for i in range(n):
                d = wrap_distance(i, self.pos, n)
                if abs(d) < VISIBLE:
                    items.append((abs(d), d, i))
            items.sort(reverse=True)           # far cards first, centre card on top
            for ad, d, i in items:
                self.draw_card(cr, d, ad, i)

            idx = int(round(self.pos)) % n
            name = os.path.splitext(os.path.basename(paths[idx]))[0]
            cr.select_font_face("JetBrainsMono Nerd Font", 0, 1)
            cr.set_font_size(17)
            ext = cr.text_extents(name)
            cr.set_source_rgba(*TEXT, 1)
            cr.move_to((W - ext.x_advance) / 2, CY + CARD_H / 2 + 44)
            cr.show_text(name)

            cr.select_font_face("JetBrainsMono Nerd Font", 0, 0)
            cr.set_font_size(13)
            counter = "%d / %d" % (idx + 1, n)
            ext = cr.text_extents(counter)
            cr.set_source_rgba(*SUBTEXT, 1)
            cr.move_to((W - ext.x_advance) / 2, CY + CARD_H / 2 + 68)
            cr.show_text(counter)

            hint = "← →"
            cr.set_font_size(12)
            ext = cr.text_extents(hint)
            cr.set_source_rgba(*OVERLAY0, 1)
            cr.move_to((W - ext.x_advance) / 2, H - 16)
            cr.show_text(hint)
            return False

        def draw_card(self, cr, d, ad, i):
            s = card_scale(ad)
            alpha = card_alpha(ad)
            if alpha <= 0.01:
                return
            sign = 1 if d >= 0 else -1
            cx = W / 2 + sign * x_offset(ad)
            cr.save()
            cr.translate(cx, CY)
            cr.scale(s, s)
            cr.translate(-CARD_W / 2, -CARD_H / 2)
            rrect(cr, 0, 0, CARD_W, CARD_H, 18)
            cr.save()
            cr.clip()
            entry = self.cache.get(i)
            if entry:
                surf, pw, ph = entry
                sc = max(CARD_W / pw, CARD_H / ph)          # cover-fit
                cr.scale(sc, sc)
                cr.set_source_surface(surf, (CARD_W / sc - pw) / 2, (CARD_H / sc - ph) / 2)
                cr.paint_with_alpha(alpha)
            else:
                cr.set_source_rgba(*SURFACE0, alpha)
                cr.paint()
            cr.restore()
            focus = max(0.0, 1.0 - ad * 1.5)
            if focus > 0:
                rrect(cr, 0, 0, CARD_W, CARD_H, 18)
                cr.set_source_rgba(*LAVENDER, focus)
                cr.set_line_width(3)
                cr.stroke()
            cr.restore()

    Carousel()
    Gtk.main()


if __name__ == "__main__":
    main()
