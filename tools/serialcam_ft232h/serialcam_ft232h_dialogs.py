import ftd2xx as ft
import time
import sys
import numpy as np

from collections import deque

import os
import threading
import queue

import argparse

# New: Import PyQt for our GUI display
from PyQt5 import QtWidgets, QtGui, QtCore

# QDialog for "capture frames"
class CaptureDialog(QtWidgets.QDialog):
    def __init__(self, settings=None, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Capture Settings")

        now = time.localtime()
        default_filename = time.strftime("capture-%Y-%m-%d_%H-%M-%S", now)
        if (settings is None):
            settings = {"frames": 1, "format": "png", "filename": default_filename, "seperate_cameras": True, "subdirectory": False}

        layout = QtWidgets.QFormLayout(self)

        self.frames_spin = QtWidgets.QSpinBox()
        self.frames_spin.setValue(settings["frames"])

        self.format_combo = QtWidgets.QComboBox()
        self.format_combo.addItems(["png", "binary", "numpy", "pbm"])
        index = self.format_combo.findText(settings["format"], QtCore.Qt.MatchFixedString)
        if index >= 0: self.format_combo.setCurrentIndex(index)

        self.filename_edit = QtWidgets.QLineEdit(settings["filename"])

        self.seperate_cams_checkbox = QtWidgets.QCheckBox()
        self.seperate_cams_checkbox.setChecked(settings["seperate_cameras"])
        self.do_subdirectory_checkbox = QtWidgets.QCheckBox()
        self.do_subdirectory_checkbox.setChecked(settings["subdirectory"])

        layout.addRow("Number of frames:", self.frames_spin)
        layout.addRow("Capture format:", self.format_combo)
        layout.addRow("Save cameras seperately:", self.seperate_cams_checkbox)
        layout.addRow("Save in new subdir:", self.do_subdirectory_checkbox)
        layout.addRow("Filename:", self.filename_edit)

        btns = QtWidgets.QDialogButtonBox(QtWidgets.QDialogButtonBox.Ok | QtWidgets.QDialogButtonBox.Cancel)
        btns.accepted.connect(self.accept)
        btns.rejected.connect(self.reject)
        layout.addRow(btns)

    def get_values(self):
        return {
            #"frames": self.frames_spin.value(),
            "frames": 1,
            "format": self.format_combo.currentText(),
            "filename": self.filename_edit.text(),
            "seperate_cameras": self.seperate_cams_checkbox.isChecked(),
            "subdirectory": self.do_subdirectory_checkbox.isChecked()
        }


class ViewOptionsDialog(QtWidgets.QDialog):
    def __init__(self, current_scale=2, current_color="gray", parent=None):
        super().__init__(parent)
        self.setWindowTitle("Viewer Options")
        layout = QtWidgets.QFormLayout(self)

        self.scale_edit = QtWidgets.QLineEdit(str(current_scale))
        layout.addRow("View scale factor:", self.scale_edit)

        # Create radio buttons
        self.cm_radio1 = QtWidgets.QRadioButton("Grayscale View")
        self.cm_radio2 = QtWidgets.QRadioButton("Color Gradient View")
        layout.addWidget(self.cm_radio1)
        layout.addWidget(self.cm_radio2)

        # Group them so only one is selectable
        self.color_map_radios = QtWidgets.QButtonGroup(self)
        self.color_map_radios.addButton(self.cm_radio1, id=0)
        self.color_map_radios.addButton(self.cm_radio2, id=1)
        if (current_color == "color"): self.color_map_radios.button(1).setChecked(True)
        else: self.color_map_radios.button(0).setChecked(True)

        # Accept / reject button
        btns = QtWidgets.QDialogButtonBox(QtWidgets.QDialogButtonBox.Ok | QtWidgets.QDialogButtonBox.Cancel)
        btns.accepted.connect(self.accept)
        btns.rejected.connect(self.reject)
        layout.addRow(btns)

        # Connect signal
        #self.color_map_radios.buttonClicked[int].connect(self.radio_changed)

    def get_values(self):
        try:
            scale = float(self.scale_edit.text())
            colormap = "color" if (self.color_map_radios.checkedId() == 1) else "gray"
        except ValueError:
            scale = None
            colormap = "gray"
        return { "scale": scale, "colormap": colormap}

class CommandWriteWidget(QtWidgets.QWidget):
    write_command = QtCore.pyqtSignal(dict)  # Custom signal to send values to parent

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Command Write")
        layout = QtWidgets.QFormLayout(self)

        monospace_font = QtGui.QFontDatabase.systemFont(QtGui.QFontDatabase.FixedFont)

        self.command_address = QtWidgets.QLineEdit()
        self.command_address.setFont(monospace_font)
        layout.addRow("Command address (hex):", self.command_address)

        self.command_data = QtWidgets.QLineEdit()
        self.command_data.setFont(monospace_font)
        layout.addRow("Command data (hex):", self.command_data)

        write_btn = QtWidgets.QPushButton("Send Command (spacebar)")
        write_btn.clicked.connect(self.send_command)
        layout.addRow(write_btn)

        self.setLayout(layout)

    def send_command(self):
        values = self.get_values()
        if values is not None:
            self.write_command.emit(values)  # Emit values to parent without closing

    def get_values(self):
        try:
            addr_bytes = int(self.command_address.text(), 16).to_bytes(2, 'little')
            data_bytes = int(self.command_data.text(), 16).to_bytes(4, 'little')
        except ValueError:
            QtWidgets.QMessageBox.warning(
                self, "Invalid Input",
                "addr must be 2 bytes of hex and data must be 4 bytes of hex"
            )
            return None

        return {"bytes": data_bytes + addr_bytes}

import re

class HomographyWidget(QtWidgets.QWidget):
    write_command = QtCore.pyqtSignal(dict)

    def __init__(self, start_addr=0x10, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Send Homography")
        layout = QtWidgets.QVBoxLayout(self)

        self.start_addr = start_addr

        # Customizable instruction label
        self.label = QtWidgets.QLabel("Paste a 3x3 matrix below that follows python formatting.")
        self.label.setWordWrap(True)
        layout.addWidget(self.label)

        # Multi-line text input
        self.textedit = QtWidgets.QTextEdit()
        monospace = QtGui.QFontDatabase.systemFont(QtGui.QFontDatabase.FixedFont)
        self.textedit.setFont(monospace)
        self.textedit.setMinimumHeight(120)
        layout.addWidget(self.textedit)

        default_text = "[[ 1.0  0.0  0.0]\n [ 0.0  1.0  0.0]\n [ 0.0  0.0  1.0]]"
        self.textedit.setPlainText(default_text)

        # Button
        send_btn = QtWidgets.QPushButton("Send Homography (spacebar)")
        send_btn.clicked.connect(self.send_command)
        layout.addWidget(send_btn)

        self.setLayout(layout)

    def send_command(self):
        values = self.get_values()
        if values is not None: self.write_command.emit(values)

    def parse_matrix_string(self, s):
        # Extract all rows: anything inside brackets [...]
        rows = re.findall(r"\[([^\[\]]+)\]", s)
        if not rows:
            raise ValueError("No valid rows found")

        matrix = []
        for row in rows:
            # Split on whitespace, convert to float
            values = list(map(float, row.strip().split()))
            matrix.append(values)

        array = np.array(matrix, dtype=float)

        if array.ndim != 2 or not np.issubdtype(array.dtype, np.floating):
            raise ValueError("Input is not a valid 2D float matrix")

        return array

    # converts from a floating point number to a sq10.8 fixed-point number that's been sign-extended
    # to 32b and converted to bytes
    def float_to_s10_q_8(self, n: float):
        return (int(np.round(n * (1 << 8))) & 0xffff_ffff).to_bytes(4, 'little')

    def get_values(self):
        return_bytes = b""
        addr = self.start_addr

        matrix = self.parse_matrix_string(self.textedit.toPlainText())

        try:
            if (matrix.shape != (3, 3)):
                raise ValueError("Invalid matrix")
        except (ValueError, SyntaxError, TypeError) as e:
            QtWidgets.QMessageBox.warning(
                self, "Invalid Input",
                "Matrix must be a 3x3 matrix of floats."
            )
            return None

        for row in matrix:
            for elt in row:
                return_bytes += self.float_to_s10_q_8(elt) + int(addr).to_bytes(2, 'little')
                addr += 1

        return {"bytes": return_bytes}

class RoiSendWidget(QtWidgets.QWidget):
    write_command = QtCore.pyqtSignal(dict)  # Custom signal to send values to parent

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Send ROI")
        layout = QtWidgets.QFormLayout(self)

        monospace_font = QtGui.QFontDatabase.systemFont(QtGui.QFontDatabase.FixedFont)

        self.roi_x = QtWidgets.QLineEdit()
        self.roi_x.setFont(monospace_font)
        layout.addRow("x (int):", self.roi_x)

        self.roi_y = QtWidgets.QLineEdit()
        self.roi_y.setFont(monospace_font)
        layout.addRow("y (int):", self.roi_y)

        send_pre_btn = QtWidgets.QPushButton("Set pre-bilinear-transform ROI")
        send_pre_btn.clicked.connect(lambda: self.send_roi_command(start_addr=0x80))
        layout.addRow(send_pre_btn)

        send_post_btn = QtWidgets.QPushButton("Set post-bilinear-transform ROI")
        send_post_btn.clicked.connect(lambda: self.send_roi_command(start_addr=0x82))
        layout.addRow(send_post_btn)

        self.setLayout(layout)

    def send_roi_command(self, start_addr=0x80):
        values = self.get_values(start_addr)
        if values is not None:
            self.write_command.emit(values)

    def get_values(self, start_addr=0x80):
        try:
            x = int(self.roi_x.text())
            y = int(self.roi_y.text())
            if x < 0 or y < 0:
                raise ValueError
            x_bytes = x.to_bytes(4, 'little')
            y_bytes = y.to_bytes(4, 'little')
        except ValueError:
            QtWidgets.QMessageBox.warning(
                self, "Invalid Input",
                "x and y must be positive integers"
            )
            return None

        addrs = [int(start_addr).to_bytes(2, 'little'), int(start_addr + 1).to_bytes(2, 'little')]

        return {"bytes": y_bytes + addrs[0] + x_bytes + addrs[1]}


class DfddParametersSendWidget(QtWidgets.QWidget):
    write_command = QtCore.pyqtSignal(dict)  # Custom signal to send values to parent

    # bits allocated to fractional portion of fixed point number for constants A and B.
    # check out verilog file containing package single_core_dfdd_fp_consts for source.
    FP_N_K = 12

    # bits allocated to fractional portion of fixed point number for constant threshold
    FP_N_THRESH = 0

    # addresses for constants in FPGA "command-mapped memory space"
    A_ADDRESS = 0x01
    B_ADDRESS = 0x02
    CONF_THRESHOLD_ADDRESS = 0x50

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Set DfDD Parameters")
        layout = QtWidgets.QFormLayout(self)

        monospace_font = QtGui.QFontDatabase.systemFont(QtGui.QFontDatabase.FixedFont)

        # A row
        a_row = QtWidgets.QHBoxLayout()
        self.dfdd_a = QtWidgets.QLineEdit()
        self.dfdd_a.setFont(monospace_font); self.dfdd_a.setText("1.000")
        a_button = QtWidgets.QPushButton("Set A")
        a_button.clicked.connect(lambda: self.send_dfdd_parameters(self.A_ADDRESS, self.dfdd_a, self.FP_N_K))
        a_row.addWidget(self.dfdd_a)
        a_row.addWidget(a_button)
        layout.addRow("A (float):", a_row)

        # B row
        b_row = QtWidgets.QHBoxLayout()
        self.dfdd_b = QtWidgets.QLineEdit()
        self.dfdd_b.setFont(monospace_font); self.dfdd_b.setText("1.000")
        b_button = QtWidgets.QPushButton("Set B")
        b_button.clicked.connect(lambda: self.send_dfdd_parameters(self.B_ADDRESS, self.dfdd_b, self.FP_N_K))
        b_row.addWidget(self.dfdd_b)
        b_row.addWidget(b_button)
        layout.addRow("B (float):", b_row)

        # Conf threshold row
        dfdd_conf_thresh_row = QtWidgets.QHBoxLayout()
        self.dfdd_conf_thresh = QtWidgets.QLineEdit()
        self.dfdd_conf_thresh.setFont(monospace_font); self.dfdd_conf_thresh.setText("10")
        dfdd_conf_thresh_button = QtWidgets.QPushButton("Set Confidence Threshold")
        dfdd_conf_thresh_button.clicked.connect(
            lambda: self.send_dfdd_parameters(self.CONF_THRESHOLD_ADDRESS,
                                              self.dfdd_conf_thresh,
                                              self.FP_N_THRESH))
        dfdd_conf_thresh_row.addWidget(self.dfdd_conf_thresh)
        dfdd_conf_thresh_row.addWidget(dfdd_conf_thresh_button)
        layout.addRow("Confidence Threshold (int):", dfdd_conf_thresh_row)

        self.setLayout(layout)

    def send_dfdd_parameters(self, start_addr, textbox, n_precision):
        values = self.get_values(start_addr, textbox.text(), n_precision)
        if values is not None:
            self.write_command.emit(values)

    def get_values(self, start_addr, text, n_precision):
        try:
            val_bytes = (int(np.round(float(text) * (1 << n_precision))) & 0xffff_ffff).to_bytes(4, 'little')
        except ValueError:
            QtWidgets.QMessageBox.warning(
                self, "Invalid Input",
                "The parameter must b a floating point number."
            )
            return None

        addr = int(start_addr).to_bytes(2, 'little')

        return {"bytes": val_bytes + addr}