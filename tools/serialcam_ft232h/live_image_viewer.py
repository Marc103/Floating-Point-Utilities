#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Live Image Viewer (fast)
------------------------
Matplotlib-based viewer for live 2D arrays with:
 - Programmatic updates via update_image()
 - Live vmin/vmax controls
 - Live colormap selection
 - Data interpretation: raw int vs float16 bit-view (reinterpret bits)
 - Optional blitting for faster redraws

Performance notes:
 - Colorbar refresh is expensive; we only update it when cmap/clim changes.
 - No autoscale each frame; optionally run once on the first frame.
 - Avoid array copies on update; use np.asarray(..., copy=False).
 - Layout is computed once; constrained_layout then disabled.

Keys:
  d : toggle interpretation (int <-> float16-view)
  c : cycle colormap
  r : reset vmin/vmax to auto (recompute once)
"""

from typing import Optional, Tuple
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.widgets import TextBox, RadioButtons

class LiveImageViewer:
    def __init__(
        self,
        shape: Tuple[int, int] = (240, 320),
        dtype=np.uint16,
        cmap: str = "gray",
        interpretation: str = "int",   # "int" | "float16-view" | "byte-decimal-view"
        vmin: Optional[float] = None,
        vmax: Optional[float] = None,
        title: str = "Live Image Viewer",
        interpolation: str = "nearest",
        blit: bool = False,
    ):
        # --- initial data/state ---
        self._raw = np.zeros(shape, dtype=dtype)
        self._interpretation = interpretation
        self._cmap = cmap
        self._vmin = vmin
        self._vmax = vmax
        self._interpolation = interpolation
        self._needs_cbar_refresh = True
        self._clim_initialized = False
        self._blit = bool(blit)
        self._bg = None  # background for blitting

        # Guard flags (avoid callback recursion)
        self._updating_cmap = False
        self._updating_dtype = False

        # --- figure/layout ---
        # Bigger figure; use constrained_layout only for the first layout pass
        self.fig = plt.figure(figsize=(12, 8.5), constrained_layout=True)
        mgr = getattr(self.fig.canvas, "manager", None)
        if mgr and hasattr(mgr, "set_window_title"):
            mgr.set_window_title(title)

        # Two columns: left (image) ~90%, right (controls) ~10%
        outer = self.fig.add_gridspec(
            nrows=1, ncols=2,
            width_ratios=[4, 1],   # ~80% : ~20%
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
            vmin=self._vmin,
            vmax=self._vmax,
            #origin="upper",
            interpolation=self._interpolation,
            animated=self._blit,
        )
        # Thin colorbar hugging the image
        self.cbar = self.fig.colorbar(
            self.im, ax=self.ax_img, shrink=0.95, pad=0.01, fraction=0.02
        )

        # Right: stacked controls in a sub-gridspec
        control_gs = outer[0, 1].subgridspec(
            nrows=6, ncols=1,
            height_ratios=[1.1, 1.1, 0.4, 2.2, 2.2, 0.9],
            hspace=0.35
        )

        # vmin / vmax TextBoxes (top)
        self.ax_vmin = self.fig.add_subplot(control_gs[0, 0])
        self.ax_vmax = self.fig.add_subplot(control_gs[1, 0])

        self.tb_vmin = TextBox(
            self.ax_vmin, "vmin:", initial="" if self._vmin is None else str(self._vmin)
        )
        self.tb_vmax = TextBox(
            self.ax_vmax, "vmax:", initial="" if self._vmax is None else str(self._vmax)
        )
        self.tb_vmin.on_submit(self._on_submit_vmin)
        self.tb_vmax.on_submit(self._on_submit_vmax)

        # Tighten TextBox fonts
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
        self._cmap_options = ["gray", "viridis", "magma", "plasma", "inferno", "jet_r"]
        active_idx = self._cmap_options.index(self._cmap) if self._cmap in self._cmap_options else 0
        self.rb_cmap = RadioButtons(self.ax_cmap, labels=self._cmap_options, active=active_idx)
        self.rb_cmap.on_clicked(self._on_cmap_clicked)

        # Make radio labels compact
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

        # Prepare blitting background if enabled
        if self._blit:
            self._grab_bg()
            self.fig.canvas.mpl_connect("draw_event", self._on_draw_event)
        self._updating_cmap = False
        self._updating_dtype = False


    # ---------- Public API ----------
    def show(self, *, block: bool = False):
        plt.show(block=block)

    def update_image(self, array: np.ndarray, *, interpretation: Optional[str] = None,
                     vmin: Optional[float] = None, vmax: Optional[float] = None,
                     cmap: Optional[str] = None) -> None:
        self._raw = np.asarray(array)

        if interpretation is not None and interpretation != self._interpretation:
            self._interpretation = interpretation

        if vmin is not None or vmax is not None:
            self._vmin = self._vmin if vmin is None else vmin
            self._vmax = self._vmax if vmax is None else vmax
            self.im.set_clim(vmin=self._vmin, vmax=self._vmax)
            self._needs_cbar_refresh = True

        if cmap is not None and cmap != self._cmap:
            self._cmap = cmap
            self.im.set_cmap(cmap)
            self._needs_cbar_refresh = True
            if cmap in self._cmap_options:
                idx = self._cmap_options.index(cmap)
                self.rb_cmap.set_active(idx)

        img = self._coerce_view(self._raw, self._interpretation)
        self.im.set_data(img)

        if not self._clim_initialized and self._vmin is None and self._vmax is None:
            data = np.asarray(img, dtype=float)
            finite = np.isfinite(data)
            if finite.any():
                self.im.set_clim(float(np.nanmin(data[finite])), float(np.nanmax(data[finite])))
                self._clim_initialized = True
                self._needs_cbar_refresh = True

        if self._needs_cbar_refresh:
            self.cbar.update_normal(self.im)
            self._needs_cbar_refresh = False
            if self._blit:
                self.fig.canvas.draw_idle()
                return

        if self._blit and self._bg is not None:
            self.fig.canvas.restore_region(self._bg)
            self.ax_img.draw_artist(self.im)
            self.fig.canvas.blit(self.ax_img.bbox)
            self.fig.canvas.flush_events()
        else:
            self.fig.canvas.draw_idle()

    def set_vmin_vmax(self, vmin: Optional[float], vmax: Optional[float]) -> None:
        self._vmin, self._vmax = vmin, vmax
        self.im.set_clim(vmin=vmin, vmax=vmax)
        self._needs_cbar_refresh = True
        self.tb_vmin.set_val("" if vmin is None else str(vmin))
        self.tb_vmax.set_val("" if vmax is None else str(vmax))

    def set_cmap(self, cmap: str) -> None:
        self._cmap = cmap
        self.im.set_cmap(cmap)
        self._needs_cbar_refresh = True

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
                self.rb_dtype.set_active(idx)
        finally:
            self._updating_dtype = False

        # Re-render image with new interpretation
        img = self._coerce_view(self._raw, self._interpretation)
        self.im.set_data(img)

        # If in auto mode, (re)compute clim once
        if self._vmin is None and self._vmax is None:
            data = np.asarray(img, dtype=float)
            finite = np.isfinite(data)
            if finite.any():
                self.im.set_clim(float(np.nanmin(data[finite])), float(np.nanmax(data[finite])))
                self._clim_initialized = True
                self._needs_cbar_refresh = True

        # Defer expensive colorbar update; draw safely
        if self._needs_cbar_refresh:
            try:
                self.cbar.update_normal(self.im)
            finally:
                self._needs_cbar_refresh = False

        # Fast draw path
        if self._blit and self._bg is not None:
            self.fig.canvas.restore_region(self._bg)
            self.ax_img.draw_artist(self.im)
            self.fig.canvas.blit(self.ax_img.bbox)
            self.fig.canvas.flush_events()
        else:
            self.fig.canvas.draw_idle()

    def _on_dtype_clicked(self, label: str) -> None:
        # Ignore callback if we’re the one changing the radio
        if getattr(self, "_updating_dtype", False):
            return
        self.set_interpretation(label)
        # No immediate colorbar update here; let draw handle it
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
            b = (a.astype(np.float32) / (2**8)) - 0.09

            # set entries where original value == 255 to NaN
            b[a == 255] = np.nan
            return b
        else:
            raise ValueError(f"Unknown interpretation: {interpretation}")

    def _on_submit_vmin(self, text: str) -> None:
        v = self._parse_optional_float(text)
        self._vmin = v
        self.im.set_clim(vmin=self._vmin, vmax=self._vmax)
        self._needs_cbar_refresh = True
        self.fig.canvas.draw_idle()

    def _on_submit_vmax(self, text: str) -> None:
        v = self._parse_optional_float(text)
        self._vmax = v
        self.im.set_clim(vmin=self._vmin, vmax=self._vmax)
        self._needs_cbar_refresh = True
        self.fig.canvas.draw_idle()

    def _on_dtype_clicked(self, label: str) -> None:
        self.set_interpretation(label)

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
            self._vmin = None
            self._vmax = None
            img = np.asarray(self.im.get_array(), dtype=float)
            finite = np.isfinite(img)
            if finite.any():
                self.im.set_clim(float(np.nanmin(img[finite])), float(np.nanmax(img[finite])))
                self._clim_initialized = True
                self._needs_cbar_refresh = True
            if self._needs_cbar_refresh:
                self.cbar.update_normal(self.im)
                self._needs_cbar_refresh = False
            self.fig.canvas.draw_idle()

    def _grab_bg(self):
        self.fig.canvas.draw()
        self._bg = self.fig.canvas.copy_from_bbox(self.ax_img.bbox)

    def _on_draw_event(self, event):
        if self._blit:
            self._grab_bg()

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
