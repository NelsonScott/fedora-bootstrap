"""User-level Variety patch, loaded via PYTHONPATH from the autostart Exec.

Pins Util.get_primary_display_size() to ~/.config/variety/screen_size
("3840x2160"). GDK misreports the size on GNOME Wayland / fractional scaling
(variety#863): 1080x1920 (portrait monitor) or 3072x1728 / 6144x3456 (scaled
virtual sizes), which renders the quote tiny and the wallpaper sub-4K.

Why not a copied Util.py: dnf overwrites files in /usr/lib on every variety
update, the copy needs root, and a whole-file copy from an older release
reverts upstream changes. This monkeypatch lives in $HOME, needs no root, and
survives package updates. It only acts when variety.Util is imported.
"""
import importlib.machinery
import os
import sys

_PIN = os.path.expanduser("~/.config/variety/screen_size")


def _patch(module):
    Util = module.Util
    orig = Util.get_primary_display_size

    def get_primary_display_size(hidpi_scaled=True):
        try:
            with open(_PIN) as f:
                w, h = f.read().strip().lower().split("x")
            return int(w), int(h)
        except Exception:
            return orig(hidpi_scaled)

    Util.get_primary_display_size = staticmethod(get_primary_display_size)


class _VarietyUtilFinder:
    def find_spec(self, name, path, target=None):
        if name != "variety.Util":
            return None
        spec = importlib.machinery.PathFinder.find_spec(name, path)
        if spec is None or spec.loader is None:
            return spec
        exec_orig = spec.loader.exec_module

        def exec_module(module):
            exec_orig(module)
            _patch(module)

        spec.loader.exec_module = exec_module
        return spec


sys.meta_path.insert(0, _VarietyUtilFinder())
