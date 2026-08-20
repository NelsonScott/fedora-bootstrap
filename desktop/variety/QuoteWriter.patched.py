# -*- Mode: Python; coding: utf-8; indent-tabs-mode: nil; tab-width: 4 -*-
### BEGIN LICENSE
# Copyright (c) 2012, Peter Levi <peterlevi@peterlevi.com>
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License version 3, as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranties of
# MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
# PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program.  If not, see <http://www.gnu.org/licenses/>.
### END LICENSE

import datetime
import math
import os
import threading

import cairo
from PIL import Image, ImageEnhance, ImageFilter

from variety.Util import Util

# keeps cairo create_for_data buffers alive
_KEEPALIVE = []

# fmt: off
import gi  # isort:skip
gi.require_version("PangoCairo", "1.0")
from gi.repository import Gdk, GdkPixbuf, GObject, Pango, PangoCairo  # isort:skip
# fmt: on


class QuoteWriter:
    @staticmethod
    def write_quote(quote, author, infile, outfile, options=None):
        done_event = threading.Event()
        exception = [None]

        def go():
            try:
                w, h = Util.get_scaled_size(infile)
                surface = QuoteWriter.load_cairo_surface(infile, w, h)
                QuoteWriter.write_quote_on_surface(surface, quote, author, options)
                QuoteWriter.save_cairo_surface(surface, outfile)
            except Exception as e:
                exception[0] = e
            finally:
                done_event.set()

        Util.add_mainloop_task(go)
        done_event.wait()
        if exception[0]:
            raise exception[0]  # pylint: disable=raising-bad-type

    @staticmethod
    def load_cairo_surface(filename, w, h):
        # pylint: disable=no-member
        pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(filename, w, h, False)
        surface = cairo.ImageSurface(0, pixbuf.get_width(), pixbuf.get_height())
        context = cairo.Context(surface)
        Gdk.cairo_set_source_pixbuf(context, pixbuf, 0, 0)
        context.paint()
        return surface

    @staticmethod
    def save_cairo_surface(surface, filename):
        try:
            # attempt faster method first
            # the get_data() call will fail with Cairo version < 1.15.4-1 (e.g. on 16.04)
            # https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=809479
            data = surface.get_data()
            size = surface.get_width(), surface.get_height()
            image = Image.frombuffer("RGBA", size, data.tobytes(), "raw", "BGRA", 0, 1).convert(
                "RGB"
            )
            image.save(filename, quality=100)
        except:
            # fallback to slower method, but which works on 16.04
            surface.write_to_png(filename)

    # ------------------------------------------------------------------
    # Quote styles from the Claude Design project "Wallpaper quote display
    # design". Values are lifted verbatim from the design's CSS; the design
    # frame is 1920x1080 and S scales it to the real screen.
    # Style is read from ~/.config/variety/quote_style ("a", "b" or "c").
    # The clock is NOT drawn here - Variety's ImageMagick clock filter owns
    # it, so it can keep refreshing every minute.
    # ------------------------------------------------------------------

    @staticmethod
    def _style():
        try:
            path = os.path.expanduser("~/.config/variety/quote_style")
            with open(path) as f:
                s = f.read().strip().lower()
            return s if s in ("a", "b", "btop", "c") else "c"
        except Exception:
            return "c"

    @staticmethod
    def _layout(ctx, text, family, px, weight=400, italic=False, width=None,
                tracking_em=0.0, line_height=None, align="left", upper=False):
        lay = PangoCairo.create_layout(ctx)
        desc = Pango.FontDescription()
        desc.set_family(family)
        desc.set_absolute_size(int(px * Pango.SCALE))
        desc.set_weight(Pango.Weight(int(weight)))
        if italic:
            desc.set_style(Pango.Style.ITALIC)
        lay.set_font_description(desc)
        if tracking_em:
            attrs = Pango.AttrList()
            attrs.insert(Pango.attr_letter_spacing_new(
                int(tracking_em * px * Pango.SCALE)))
            lay.set_attributes(attrs)
        if line_height:
            lay.set_line_spacing(line_height)
        if width:
            lay.set_width(int(width * Pango.SCALE))
            lay.set_wrap(Pango.WrapMode.WORD)
        lay.set_alignment({"left": Pango.Alignment.LEFT,
                           "center": Pango.Alignment.CENTER,
                           "right": Pango.Alignment.RIGHT}[align])
        lay.set_text(text.upper() if upper else text, -1)
        return lay

    @staticmethod
    def _surface_to_pil(surf):
        surf.flush()
        return Image.frombuffer(
            "RGBA", (surf.get_width(), surf.get_height()),
            bytes(surf.get_data()), "raw", "BGRA", surf.get_stride(), 1).copy()

    @staticmethod
    def _pil_to_surface(img):
        img = img.convert("RGBA")
        r, g, b, a = img.split()
        data = bytearray(Image.merge("RGBA", (b, g, r, a)).tobytes())
        _KEEPALIVE.append(data)
        del _KEEPALIVE[:-24]
        return cairo.ImageSurface.create_for_data(
            data, cairo.FORMAT_ARGB32, img.width, img.height, img.width * 4)

    @staticmethod
    def _shadowed(surface, x, y, lay, rgba=(1, 1, 1, 1), shadows=()):
        """Draw a Pango layout with genuinely blurred drop shadows."""
        lw, lh = lay.get_pixel_size()
        pad = 80
        for dx, dy, blur, alpha in shadows:
            scratch = cairo.ImageSurface(
                cairo.FORMAT_ARGB32, lw + pad * 2, lh + pad * 2)
            sctx = cairo.Context(scratch)
            sctx.set_source_rgba(0, 0, 0, 1)
            sctx.move_to(pad, pad)
            PangoCairo.show_layout(sctx, lay)
            if blur > 0:
                scratch = QuoteWriter._pil_to_surface(
                    QuoteWriter._surface_to_pil(scratch).filter(
                        ImageFilter.GaussianBlur(blur)))
            ctx = cairo.Context(surface)
            ctx.set_source_surface(scratch, x - pad + dx, y - pad + dy)
            ctx.paint_with_alpha(alpha)
        ctx = cairo.Context(surface)
        ctx.set_source_rgba(*rgba)
        ctx.move_to(x, y)
        PangoCairo.show_layout(ctx, lay)

    @staticmethod
    def _rounded_rect(ctx, x, y, w, h, r):
        ctx.new_sub_path()
        ctx.arc(x + w - r, y + r, r, -math.pi / 2, 0)
        ctx.arc(x + w - r, y + h - r, r, 0, math.pi / 2)
        ctx.arc(x + r, y + h - r, r, math.pi / 2, math.pi)
        ctx.arc(x + r, y + r, r, math.pi, 3 * math.pi / 2)
        ctx.close_path()

    @staticmethod
    def write_quote_on_surface(surface, quote, author=None, options=None, margin=30):
        sw, sh = Util.get_primary_display_size(hidpi_scaled=True)
        iw, ih = surface.get_width(), surface.get_height()
        ox, oy = Util.compute_trimmed_offsets((iw, ih), (sw, sh))
        S = sw / 1920.0
        style = QuoteWriter._style()

        author = author or ""
        has_author = bool(author.strip())
        # CSS text-shadow stacks from the design, scaled to device pixels
        tshadow = [(0, 1 * S, 1 * S, 1.0), (0, 1 * S, 4 * S, 0.95),
                   (0, 3 * S, 10 * S, 0.8), (0, 6 * S, 28 * S, 0.65)]

        ctx = cairo.Context(surface)

        if style in ("b", "btop"):
            pass
        if style == "a":
            # 1a - sleek modern: radial scrim, 2px hairline, Space Grotesk
            ctx.save()
            ctx.translate(ox + sw / 2, oy + sh / 2)
            ctx.scale(0.55 * sw, 0.45 * sh)
            grad = cairo.RadialGradient(0, 0, 0, 0, 0, 1)
            grad.add_color_stop_rgba(0.0, 8 / 255, 10 / 255, 9 / 255, 0.55)
            grad.add_color_stop_rgba(0.55, 8 / 255, 10 / 255, 9 / 255, 0.25)
            grad.add_color_stop_rgba(0.78, 8 / 255, 10 / 255, 9 / 255, 0.0)
            ctx.set_source(grad)
            ctx.arc(0, 0, 1, 0, 2 * math.pi)
            ctx.fill()
            ctx.restore()

            box_w, rule_w, gap = 440 * S, 2 * S, 16 * S
            q = QuoteWriter._layout(ctx, quote, "Space Grotesk", 21 * S,
                                    weight=300, width=box_w - rule_w - gap,
                                    line_height=1.45)
            a = QuoteWriter._layout(ctx, author, "Space Grotesk", 11.5 * S,
                                    weight=400, tracking_em=0.18, upper=True)
            qh = q.get_pixel_size()[1]
            ah = a.get_pixel_size()[1] if has_author else 0
            inner = 12 * S if has_author else 0
            total = qh + inner + ah
            # design anchors the block bottom-left of the visible frame
            x0 = ox + 96 * S
            y0 = oy + sh - 150 * S - total

            ctx.set_source_rgba(1, 1, 1, 0.85)
            ctx.rectangle(x0, y0, rule_w, total)
            ctx.fill()
            tx = x0 + rule_w + gap
            QuoteWriter._shadowed(surface, tx, y0, q, (1, 1, 1, 1), tshadow)
            if has_author:
                QuoteWriter._shadowed(surface, tx, y0 + qh + inner, a,
                                      (1, 1, 1, 1), tshadow)

        elif style in ("b", "btop"):
            # 1b - classic: bottom gradient, centred Cormorant italic
            grad = cairo.LinearGradient(0, oy + sh, 0, oy)
            grad.add_color_stop_rgba(0.0, 8 / 255, 10 / 255, 9 / 255, 0.66)
            grad.add_color_stop_rgba(0.26, 8 / 255, 10 / 255, 9 / 255, 0.28)
            grad.add_color_stop_rgba(0.46, 8 / 255, 10 / 255, 9 / 255, 0.0)
            ctx.set_source(grad)
            ctx.rectangle(ox, oy, sw, sh)
            ctx.fill()

            box_w = 620 * S
            cx = ox + sw / 2
            q = QuoteWriter._layout(ctx, quote, "Cormorant Garamond", 27 * S,
                                    weight=500, italic=True, width=box_w,
                                    line_height=1.42, align="center")
            a = QuoteWriter._layout(ctx, author, "Cormorant Garamond", 15 * S,
                                    tracking_em=0.22, upper=True)
            qh = q.get_pixel_size()[1]
            aw, ah = a.get_pixel_size() if has_author else (0, 0)
            gap = 14 * S
            gap2 = gap if has_author else 0
            total = qh + gap2 + ah
            y0 = oy + sh - 64 * S - total

            QuoteWriter._shadowed(surface, cx - box_w / 2, y0, q,
                                  (1, 1, 1, 1), tshadow)
            ay = y0 + qh + gap2
            if has_author:
                QuoteWriter._shadowed(surface, cx - aw / 2, ay, a,
                                      (1, 1, 1, 1), tshadow)
            if aw > 0:
                ctx = cairo.Context(surface)
                ctx.set_source_rgba(1, 1, 1, 0.55)
                rl, rg = 36 * S, 14 * S
                ry = ay + ah / 2
                ctx.rectangle(cx - aw / 2 - rg - rl, ry, rl, max(1, 1 * S))
                ctx.rectangle(cx + aw / 2 + rg, ry, rl, max(1, 1 * S))
                ctx.fill()

            if style == "btop":
                # identical treatment to the quote: Cormorant italic 500,
                # same size, same blurred shadow stack. No attribution styling.
                now = datetime.datetime.now()
                text = now.strftime("%-I:%M %p") + "\n" + now.strftime("%A, %B %-d")
                ctx = cairo.Context(surface)
                cl = QuoteWriter._layout(ctx, text, "Cormorant Garamond",
                                         27 * S, weight=500, italic=True,
                                         width=box_w, line_height=1.42,
                                         align="center")
                QuoteWriter._shadowed(surface, cx - box_w / 2, oy + 64 * S, cl,
                                      (1, 1, 1, 1), tshadow)

        else:
            # 1c - frosted glass card, wallpaper-proof
            card_w = 340 * S
            pad_x, pad_y, radius = 30 * S, 28 * S, 16 * S
            inner_w = card_w - pad_x * 2
            label = QuoteWriter._layout(ctx, "QUOTE OF THE DAY",
                                        "IBM Plex Mono", 10.5 * S,
                                        tracking_em=0.24)
            q = QuoteWriter._layout(ctx, quote, "Space Grotesk", 19 * S,
                                    width=inner_w, line_height=1.5)
            a = QuoteWriter._layout(ctx, "— " + author, "IBM Plex Mono",
                                    12 * S, width=inner_w)
            lh = label.get_pixel_size()[1]
            qh = q.get_pixel_size()[1]
            ah = a.get_pixel_size()[1] if has_author else 0
            gap = 16 * S
            gap2 = gap if has_author else 0
            card_h = pad_y * 2 + lh + gap + qh + gap2 + ah
            cx = ox + sw - 48 * S - card_w
            cy = oy + sh / 2 - card_h / 2

            region = QuoteWriter._surface_to_pil(surface).crop(
                (int(cx), int(cy), int(cx + card_w), int(cy + card_h)))
            region = region.filter(ImageFilter.GaussianBlur(18 * S))
            region = ImageEnhance.Color(region).enhance(1.1)
            blurred = QuoteWriter._pil_to_surface(region)

            ctx = cairo.Context(surface)
            ctx.save()
            QuoteWriter._rounded_rect(ctx, cx, cy, card_w, card_h, radius)
            ctx.clip()
            ctx.set_source_surface(blurred, cx, cy)
            ctx.paint()
            ctx.set_source_rgba(14 / 255, 16 / 255, 15 / 255, 0.42)
            ctx.paint()
            ctx.restore()

            QuoteWriter._rounded_rect(ctx, cx + S / 2, cy + S / 2,
                                      card_w - S, card_h - S, radius)
            ctx.set_source_rgba(1, 1, 1, 0.14)
            ctx.set_line_width(max(1, 1 * S))
            ctx.stroke()

            tx, ty = cx + pad_x, cy + pad_y
            QuoteWriter._shadowed(surface, tx, ty, label, (1, 1, 1, 0.55), ())
            QuoteWriter._shadowed(surface, tx, ty + lh + gap, q, (1, 1, 1, 1), ())
            if has_author:
                QuoteWriter._shadowed(surface, tx, ty + lh + gap + qh + gap2, a,
                                      (1, 1, 1, 0.68), ())


if __name__ == "__main__":
    QuoteWriter.write_quote(
        '"I may be drunk, Miss, but in the morning I will be sober and you will still be ugly."',
        "Winston Churchill",
        "test.jpg",
        "test_result.png",
    )
