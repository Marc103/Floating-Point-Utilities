#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Live Image Viewer (constant-cost, no blitting)

- No blitting: same draw path every frame (set_data + draw_idle).
- Fixed normalization via matplotlib.colors.Normalize (no per-frame min/max).
- Colorbar updates only when user changes vmin/vmax or cmap.
- Interpretation modes unchanged ("int", "float16-view", "byte-decimal-view").
"""

from typing import Optional, Tuple
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.widgets import TextBox, RadioButtons
from matplotlib.colors import Normalize


class LiveImageViewer:
    def __init__(
        self,
        shape: Tuple[int, int] = (400, 480),
        dtype=np.uint16,
        cmap: str = "gray",
        interpretation: str = "int",   # "int" | "float16-view" | "byte-decimal-view"
        vmin: Optional[float] = 0.0,
        vmax: Optional[float] = 255.0,
        title: str = "Live Image Viewer",
        interpolation: str = "nearest",
        blit: bool = False,            # accepted but ignored (we disable blitting)
    ):
        # --- initial data/state ---
        self._raw = np.zeros(shape, dtype=dtype)
        self._interpretation = interpretation
        self._cmap = cmap
        self._vmin = vmin
        self._vmax = vmax
        self._interpolation = interpolation
        self._needs_cbar_refresh = True

        # No blitting: keep flags for API compatibility, but never use them
        self._blit = False
        self._bg = None

        # Guard flags (avoid callback recursion)
        self._updating_cmap = False
        self._updating_dtype = False

        # Fixed normalization → constant work per frame
        self._norm = Normalize(vmin=self._vmin, vmax=self._vmax, clip=True)

        # --- figure/layout ---
        self.fig = plt.figure(figsize=( 12, 8.5), constrained_layout=True)
        mgr = getattr(self.fig.canvas, "manager", None)
        if mgr and hasattr(mgr, "set_window_title"):
            mgr.set_window_title(title)

        # Two columns: left image (~80%), right controls (~20%)
        outer = self.fig.add_gridspec(
            nrows=1, ncols=2,
            width_ratios=[4, 1],
            wspace=0.04
        )

        # Left: image axes
        self.ax_img = self.fig.add_subplot(outer[0, 0])
        self.ax_img.set_title(title)
        self.ax_img.set_axis_off()

        img = self._coerce_view(self._raw, self._interpretation)
        self.im = self.ax_img.imshow(
            img,
            cmap=self._cmap,
            norm=self._norm,                  # fixed Normalize
            interpolation=self._interpolation,
            animated=False,                   # ensure non-blitting
            aspect="equal",
        )

        # Colorbar created once; refresh only on user changes
        self.cbar = self.fig.colorbar(
            self.im, ax=self.ax_img, shrink=0.95, pad=0.01, fraction=0.02
        )

        # Right: stacked controls
        control_gs = outer[0, 1].subgridspec(
            nrows=6, ncols=1,
            height_ratios=[1.1, 1.1, 0.4, 2.2, 2.2, 0.9],
            hspace=0.35
        )

        # vmin / vmax TextBoxes
        self.ax_vmin = self.fig.add_subplot(control_gs[0, 0])
        self.ax_vmax = self.fig.add_subplot(control_gs[1, 0])
        self.tb_vmin = TextBox(self.ax_vmin, "vmin:", initial="" if self._vmin is None else str(self._vmin))
        self.tb_vmax = TextBox(self.ax_vmax, "vmax:", initial="" if self._vmax is None else str(self._vmax))
        self.tb_vmin.on_submit(self._on_submit_vmin)
        self.tb_vmax.on_submit(self._on_submit_vmax)
        try:
            for tb in (self.tb_vmin, self.tb_vmax):
                tb.text_disp.set_fontsize(8)
                tb.label.set_fontsize(8)
        except Exception:
            pass

        # Interpretation radios
        self.ax_dtype = self.fig.add_subplot(control_gs[3, 0])
        self.ax_dtype.set_title("Interpretation", fontsize=9, pad=6)
        self.rb_dtype = RadioButtons(
            self.ax_dtype,
            labels=["int", "float16-view", "byte-decimal-view"],
            active={"int": 0, "float16-view": 1, "byte-decimal-view": 2}.get(self._interpretation, 0),
        )
        self.rb_dtype.on_clicked(self._on_dtype_clicked)

        # Colormap radios
        self.ax_cmap = self.fig.add_subplot(control_gs[4, 0])
        self.ax_cmap.set_title("Colormap", fontsize=9, pad=6)
        self._cmap_options = ["gray", "viridis", "magma", "plasma", "inferno", "jet"]
        active_idx = self._cmap_options.index(self._cmap) if self._cmap in self._cmap_options else 0
        self.rb_cmap = RadioButtons(self.ax_cmap, labels=self._cmap_options, active=active_idx)
        self.rb_cmap.on_clicked(self._on_cmap_clicked)

        for txt in list(self.rb_dtype.labels) + list(self.rb_cmap.labels):
            txt.set_fontsize(8)

        # Keyboard shortcuts
        self.fig.canvas.mpl_connect("key_press_event", self._on_key)

        # Finalize initial layout, then disable recomputation for speed
        self.fig.canvas.draw()
        try:
            self.fig.set_constrained_layout(False)
        except Exception:
            pass

    # ---------- Public API ----------
    def show(self, *, block: bool = False):
        plt.show(block=block)

    def update_image(self, array: np.ndarray, *, interpretation: Optional[str] = None,
                     vmin: Optional[float] = None, vmax: Optional[float] = None,
                     cmap: Optional[str] = None) -> None:
        # Convert reference; caller can ensure contiguity upstream if needed
        self._raw = np.asarray(array)

        if interpretation is not None and interpretation != self._interpretation:
            self._interpretation = interpretation

        # Only change normalization if explicitly requested (constant work)
        if (vmin is not None) or (vmax is not None):
            self._vmin = self._vmin if vmin is None else vmin
            self._vmax = self._vmax if vmax is None else vmax
            self._norm.vmin = self._vmin
            self._norm.vmax = self._vmax
            self._needs_cbar_refresh = True

        if cmap is not None and cmap != self._cmap:
            self._cmap = cmap
            self.im.set_cmap(cmap)
            self._needs_cbar_refresh = True
            if cmap in self._cmap_options:
                idx = self._cmap_options.index(cmap)
                if idx != self.rb_cmap.active:
                    self.rb_cmap.set_active(idx)

        # Set new pixels (no autoscale)
        img = self._coerce_view(self._raw, self._interpretation)
        self.im.set_data(img)

        # Only refresh colorbar when needed (constant cost otherwise)
        if self._needs_cbar_refresh:
            self.cbar.update_normal(self.im)
            self._needs_cbar_refresh = False

        # Single draw path (no blitting)
        self.fig.canvas.draw_idle()

    def set_vmin_vmax(self, vmin: Optional[float], vmax: Optional[float]) -> None:
        self._vmin, self._vmax = vmin, vmax
        self._norm.vmin, self._norm.vmax = vmin, vmax
        self._needs_cbar_refresh = True
        self.tb_vmin.set_val("" if vmin is None else str(vmin))
        self.tb_vmax.set_val("" if vmax is None else str(vmax))
        self.fig.canvas.draw_idle()

    def set_cmap(self, cmap: str) -> None:
        if cmap == self._cmap:
            return
        self._cmap = cmap
        self.im.set_cmap(cmap)
        self._needs_cbar_refresh = True
        self.fig.canvas.draw_idle()

    def set_interpretation(self, interpretation: str) -> None:
        if interpretation not in ("int", "float16-view", "byte-decimal-view"):
            return
        if interpretation == self._interpretation:
            return
        self._interpretation = interpretation

        # Prevent callback recursion when syncing the radio UI
        self._updating_dtype = True
        try:
            if hasattr(self, "rb_dtype"):
                idx = {"int": 0, "float16-view": 1, "byte-decimal-view": 2}[interpretation]
                if idx != self.rb_dtype.active:
                    self.rb_dtype.set_active(idx)
        finally:
            self._updating_dtype = False

        # Re-render image with new interpretation (no autoscan)
        img = self._coerce_view(self._raw, self._interpretation)
        self.im.set_data(img)

        if self._needs_cbar_refresh:
            self.cbar.update_normal(self.im)
            self._needs_cbar_refresh = False

        self.fig.canvas.draw_idle()

    # ---------- Internals ----------
    def _coerce_view(self, arr: np.ndarray, interpretation: str) -> np.ndarray:
        if interpretation == "int":
            return np.asarray(arr)
        elif interpretation == "float16-view":
            a = np.asarray(arr)
            if a.dtype == np.uint16 or a.dtype == np.int16:
                return a.view(np.float16)
            if a.dtype == np.uint32 or a.dtype == np.int32:
                b = (a & 0xFFFF).astype(np.uint16)
                return b.view(np.float16)
            if a.dtype == np.uint8:
                if a.ndim != 2:
                    raise TypeError("float16-view expects a 2D array; got shape %r" % (a.shape,))
                if a.size % 2 != 0:
                    raise ValueError("Total number of bytes must be even to reinterpret as float16.")
                b = a.view(np.uint16)
                return b.view(np.float16)
            raise TypeError(f"Unsupported dtype {a.dtype} for float16-view")
        elif interpretation == "byte-decimal-view":
            a = np.asarray(arr)
            b = (a.astype(np.float32) / (2**8))
            b[a == 255] = np.nan
            return b
        else:
            raise ValueError(f"Unknown interpretation: {interpretation}")

    def _on_submit_vmin(self, text: str) -> None:
        v = self._parse_optional_float(text)
        self._vmin = v
        self._norm.vmin = v
        self._needs_cbar_refresh = True
        self.fig.canvas.draw_idle()

    def _on_submit_vmax(self, text: str) -> None:
        v = self._parse_optional_float(text)
        self._vmax = v
        self._norm.vmax = v
        self._needs_cbar_refresh = True
        self.fig.canvas.draw_idle()

    def _on_dtype_clicked(self, label: str) -> None:
        if getattr(self, "_updating_dtype", False):
            return
        self.set_interpretation(label)
        self.fig.canvas.draw_idle()

    def _on_cmap_clicked(self, label: str) -> None:
        self.set_cmap(label)
        if self._needs_cbar_refresh:
            self.cbar.update_normal(self.im)
            self._needs_cbar_refresh = False
        self.fig.canvas.draw_idle()

    def _parse_optional_float(self, text: str) -> Optional[float]:
        t = text.strip()
        if t == "" or t.lower() in ("none", "auto"):
            return None
        try:
            return float(t)
        except ValueError:
            return None

    def _on_key(self, event) -> None:
        if event.key in ("c", "C"):
            labels = [t.get_text() for t in self.rb_cmap.labels]
            idx = labels.index(self._cmap) if self._cmap in labels else 0
            idx = (idx + 1) % len(labels)
            self.set_cmap(labels[idx])
            if self._needs_cbar_refresh:
                self.cbar.update_normal(self.im)
                self._needs_cbar_refresh = False
            self.fig.canvas.draw_idle()
        elif event.key in ("d", "D"):
            self.set_interpretation("float16-view" if self._interpretation == "int" else "int")
        elif event.key in ("r", "R"):
            # One-time autoscale from current frame, then fix it
            img = np.asarray(self.im.get_array(), dtype=float)
            finite = np.isfinite(img)
            if finite.any():
                vmin = float(np.nanmin(img[finite]))
                vmax = float(np.nanmax(img[finite]))
                self._vmin, self._vmax = vmin, vmax
                self._norm.vmin, self._norm.vmax = vmin, vmax
                self._needs_cbar_refresh = True
            self.fig.canvas.draw_idle()


# ---------------- Demo ----------------
def _demo_stream(view_seconds: float = 10.0, channels: int = 1, blit: bool = False) -> None:
    rng = np.random.default_rng(42)
    viewers = []
    for i in range(channels):
        v = LiveImageViewer(shape=(240, 320), dtype=np.uint16,
                            title=f"Viewer {i}", blit=blit)
        viewers.append(v)

    plt.ion()
    plt.show(block=False)

    import time
    t0 = time.time()
    base = rng.integers(0, 65535, size=(240, 320), dtype=np.uint16)
    while time.time() - t0 < view_seconds:
        shift = int((time.time() - t0) * 60) % base.shape[1]
        frame = np.roll(base, shift=shift, axis=1)
        noise = rng.integers(0, 256, size=frame.shape, dtype=np.uint16)
        frame = (frame + noise).astype(np.uint16)

        for v in viewers:
            v.update_image(frame)

        plt.pause(0.01)

    plt.ioff()
    plt.show()

if __name__ == "__main__":
    _demo_stream(view_seconds=10.0, channels=2, blit=True)
